// Lifecycle test for FfiEngineDataSource against the real native engine on
// miniaudio's null backend (T043a).
import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/data/datasources/engine_data_source.dart';
import 'package:mute_around/features/pipeline/data/datasources/ffi_engine_data_source.dart';

import '../../../../core/native/null_backend.dart';

void main() {
  setUpAll(useNullAudioBackend);

  test('init/start/stop/dispose with status changes', () async {
    final source = FfiEngineDataSource();
    final statuses = <EngineStatus>[];
    final sub = source.status.listen(statuses.add);

    final capture = source.listDevices(.capture).valueOrNull!;
    final playback = source.listDevices(.playback).valueOrNull!;
    expect(capture.map((d) => d.id), contains('null:0'));
    expect(capture.every((d) => d.name.isNotEmpty), isTrue);
    expect(playback, isNotEmpty);

    expect(source.setStrength(.low), const Ok(unit));
    expect(source.setAgc(enabled: false), const Ok(unit));
    expect(source.setBypass(enabled: false), const Ok(unit));

    expect(
      source.start(captureId: capture.first.id, sinkId: playback.first.id),
      const Ok(unit),
    );
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(source.setBypass(enabled: true), const Ok(unit));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(source.stop(), const Ok(unit));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    // The engine is created and started within one poll interval, so the
    // first status seen is `running`.
    expect(statuses, [
      EngineStatus.running,
      EngineStatus.bypassedUser,
      EngineStatus.stopped,
    ]);
    await sub.cancel();
    await source.dispose();
  });

  test('errors become Failures and never throw', () async {
    final source = FfiEngineDataSource();
    addTearDown(source.dispose);
    expect(source.stop().failureOrNull, isA<EngineStateFailure>());
    expect(
      source.start(captureId: 'no-such-mic').failureOrNull,
      isA<DeviceNotFound>().having(
        (f) => f.detail,
        'detail',
        contains('no-such-mic'),
      ),
    );
    expect(source.start(), const Ok(unit));
    expect(source.start().failureOrNull, isA<EngineStateFailure>());
  });

  test('an unloadable model is a ModelLoadFailure', () async {
    final source = FfiEngineDataSource(modelPath: '/does/not/exist.tar.gz');
    addTearDown(source.dispose);
    expect(source.listDevices(.capture).failureOrNull, isA<ModelLoadFailure>());
  });

  test('poll rate is 30 Hz visible and 4 Hz hidden', () async {
    final source = FfiEngineDataSource();
    addTearDown(source.dispose);
    expect(source.pollInterval, const Duration(milliseconds: 33));
    source.setVisible(visible: false);
    expect(source.pollInterval, const Duration(milliseconds: 250));
    source.setVisible(visible: true);
    expect(source.pollInterval, const Duration(milliseconds: 33));
  });

  test('dispose closes the status stream; calls after dispose fail', () async {
    final source = FfiEngineDataSource();
    expect(source.start(), const Ok(unit));
    var done = false;
    source.status.listen(null, onDone: () => done = true);
    await source.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(done, isTrue);
    expect(source.stop().failureOrNull, isA<EngineStateFailure>());
    await source.dispose(); // idempotent
  });
}
