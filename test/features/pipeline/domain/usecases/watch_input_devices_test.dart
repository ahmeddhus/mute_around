import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device_snapshot.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_input_devices.dart';

class MockAudioEngineRepository extends Mock implements AudioEngineRepository {}

void main() {
  late MockAudioEngineRepository engine;
  late List<Result<List<InputDevice>>> polls;

  final builtIn = InputDevice(id: 'builtin', name: 'MacBook Mic');
  final usb = InputDevice(id: 'usb', name: 'USB Mic');

  setUp(() {
    engine = MockAudioEngineRepository();
    polls = [];
    when(() => engine.listInputDevices()).thenAnswer(
      (_) async => polls.length > 1 ? polls.removeAt(0) : polls.first,
    );
  });

  List<InputDeviceSnapshot> run(
    String? Function() selected, {
    int ticks = 3,
  }) {
    final out = <InputDeviceSnapshot>[];
    fakeAsync((async) {
      final sub = WatchInputDevices(engine)(
        selectedId: selected,
      ).listen(out.add);
      async.flushMicrotasks();
      async.elapse(Duration(seconds: 2 * (ticks - 1)));
      unawaited(sub.cancel());
      async.flushMicrotasks();
    });
    return out;
  }

  test('polls every 2 s and reports added and removed ids', () {
    polls = [
      Ok([builtIn]),
      Ok([builtIn, usb]),
      Ok([usb]),
    ];
    final out = run(() => null);
    expect(out, hasLength(3));
    expect(out[0].hasChanges, isFalse);
    expect(out[1].added, {'usb'});
    expect(out[2].removed, {'builtin'});
    expect(out[2].devices, [usb]);
  });

  test('emits on every poll, changed or not (retry tick)', () {
    polls = [
      Ok([builtIn]),
    ];
    final out = run(() => null);
    expect(out, hasLength(3));
    expect(out.every((s) => !s.hasChanges), isTrue);
  });

  test(
    'a missing selected device stays, marked disconnected, with its name',
    () {
      polls = [
        Ok([builtIn, usb]),
        Ok([builtIn]),
      ];
      final out = run(() => 'usb', ticks: 2);
      final missing = out.last.devices.last;
      expect(missing.id, 'usb');
      expect(missing.isConnected, isFalse);
      expect(missing.name, 'USB Mic');
      expect(out.last.connected, [builtIn]);
    },
  );

  test('an unknown selected device gets a fallback name', () {
    polls = [
      Ok([builtIn]),
    ];
    final out = run(() => 'gone-abcdef', ticks: 1);
    expect(out.single.devices.last.name, 'Microphone (abcdef)');
  });

  test('failed polls are skipped', () {
    polls = [
      const Err(DeviceFailure()),
      Ok([builtIn]),
    ];
    final out = run(() => null, ticks: 2);
    expect(out, hasLength(1));
    expect(out.single.devices, [builtIn]);
  });

  test('stops polling when the listener cancels', () {
    polls = [
      Ok([builtIn]),
    ];
    run(() => null, ticks: 2);
    verify(() => engine.listInputDevices()).called(2);
  });
}
