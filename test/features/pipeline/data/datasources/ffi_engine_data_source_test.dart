// Lifecycle test for FfiEngineDataSource against the real native engine on
// miniaudio's null backend (T043a).
import 'package:flutter_test/flutter_test.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/data/datasources/engine_data_source.dart';
import 'package:mute_around/features/pipeline/data/datasources/ffi_engine_data_source.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';

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

  test('switchInput: keeps running; errors are Failures', () async {
    final source = FfiEngineDataSource();
    addTearDown(source.dispose);
    expect(
      source.switchInput('null:0').failureOrNull,
      isA<EngineStateFailure>(),
    );
    final capture = source.listDevices(.capture).valueOrNull!;
    expect(source.start(captureId: capture.first.id), const Ok(unit));
    expect(source.switchInput(capture.first.id), const Ok(unit));
    expect(
      source.switchInput('no-such-mic').failureOrNull,
      isA<DeviceNotFound>(),
    );
    expect(source.stop(), const Ok(unit));
  });

  test(
    'levels: polled while listened and visible, paused when hidden',
    () async {
      final source = FfiEngineDataSource();
      addTearDown(source.dispose);
      expect(source.start(), const Ok(unit));
      final readings = <AudioLevels>[];
      final sub = source.levels.listen(readings.add);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(readings.length, inInclusiveRange(3, 8)); // ~30 Hz
      for (final l in readings) {
        for (final db in [
          l.inputPeakDb,
          l.inputRmsDb,
          l.outputPeakDb,
          l.outputRmsDb,
        ]) {
          expect(db, inInclusiveRange(-90, 0));
        }
      }
      source.setVisible(visible: false);
      // A broadcast stream delivers events in a later microtask, so a reading
      // taken just before hiding can still be on its way. Let it land before
      // counting; only readings after this point would mean polling went on.
      await Future<void>.delayed(Duration.zero);
      final hiddenStart = readings.length;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(readings.length, hiddenStart);
      source.setVisible(visible: true);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(readings.length, greaterThan(hiddenStart));
      await sub.cancel();
    },
  );

  test('stats count processed frames while running', () async {
    final source = FfiEngineDataSource();
    addTearDown(source.dispose);
    expect(source.start(), const Ok(unit));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final stats = source.stats().valueOrNull!;
    expect(stats.framesProcessed, greaterThan(0));
    expect(stats.estimatedLatencyMs, inInclusiveRange(1, 50));
    expect(source.stop(), const Ok(unit));
    expect(source.stats().valueOrNull!.estimatedLatencyMs, 0);
  });
}
