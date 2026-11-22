// Lifecycle and error-path tests against the real native engine,
// on miniaudio's null backend so no audio hardware is needed.
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/core/native/engine_library.dart';
import 'package:mute_around/core/native/mute_engine.ffigen.dart';
import 'package:mute_around/core/result.dart';

import 'null_backend.dart';

Pointer<me_engine> createEngine([String? modelPath]) => using((arena) {
  final out = arena<Pointer<me_engine>>();
  final path = modelPath == null ? nullptr : toCString(modelPath, arena);
  final r = me_engine_create(path, out);
  expect(r, ME_OK);
  return out.value;
});

List<String> captureIds(Pointer<me_engine> engine) => using((arena) {
  final buf = arena<me_device_info>(16);
  final n = me_list_devices(engine, ME_DEVICE_CAPTURE, buf, 16);
  expect(n, greaterThanOrEqualTo(0));
  return [for (var i = 0; i < n; i++) readCString(buf[i].id, ME_DEVICE_ID_MAX)];
});

void main() {
  setUpAll(useNullAudioBackend);

  test('ABI major version matches the bindings', () {
    expect(me_abi_version() >> 16, ME_ABI_VERSION_MAJOR);
    expect(checkEngineAbi(), const Ok(unit));
    expect(checkEngineAbi(abiVersion: () => 2 << 16).isOk, isFalse);
  });

  test('create and destroy; destroying NULL is safe', () {
    final engine = createEngine();
    expect(engine, isNot(nullptr));
    expect(me_get_status(engine), ME_STATUS_STOPPED);
    me_engine_destroy(engine);
    me_engine_destroy(nullptr);
  });

  test('an invalid model path fails with ME_ERR_MODEL', () {
    using((arena) {
      final out = arena<Pointer<me_engine>>();
      final r = me_engine_create(
        toCString('/does/not/exist.tar.gz', arena),
        out,
      );
      expect(r, ME_ERR_MODEL);
      expect(out.value, nullptr);
    });
  });

  test('full lifecycle on the null backend', () async {
    final engine = createEngine();
    addTearDown(() => me_engine_destroy(engine));

    // stop before start
    expect(me_engine_stop(engine), ME_ERR_STATE);

    // setters before start succeed and survive start
    me_set_strength(engine, ME_STRENGTH_HIGH);
    me_set_agc(engine, 0);
    me_set_bypass(engine, 1);

    expect(captureIds(engine), contains('null:0'));
    expect(me_engine_start(engine, nullptr, nullptr), ME_OK);
    expect(me_get_status(engine), ME_STATUS_BYPASSED_USER);
    me_set_bypass(engine, 0);
    expect(me_get_status(engine), ME_STATUS_RUNNING);

    // start twice
    expect(me_engine_start(engine, nullptr, nullptr), ME_ERR_STATE);

    // audio flows through the processing thread
    await Future<void>.delayed(const Duration(milliseconds: 300));
    using((arena) {
      final stats = arena<me_stats>();
      me_get_stats(engine, stats);
      expect(stats.ref.frames_processed, greaterThan(0));
    });

    // switch input while running, then stop
    expect(me_engine_switch_input(engine, nullptr), ME_OK);
    expect(me_get_status(engine), ME_STATUS_RUNNING);
    expect(me_engine_stop(engine), ME_OK);
    expect(me_get_status(engine), ME_STATUS_STOPPED);
    expect(me_engine_switch_input(engine, nullptr), ME_ERR_STATE);
  });

  test('starting with an unknown capture id fails with ME_ERR_NOT_FOUND', () {
    final engine = createEngine();
    addTearDown(() => me_engine_destroy(engine));
    using((arena) {
      final r = me_engine_start(
        engine,
        toCString('no-such-mic', arena),
        nullptr,
      );
      expect(r, ME_ERR_NOT_FOUND);
      expect(me_get_status(engine), ME_STATUS_STOPPED);
      final buf = arena<Char>(256);
      expect(me_last_error(engine, buf, 256), ME_OK);
      expect(buf.cast<Utf8>().toDartString(), contains('no-such-mic'));
    });
  });
}
