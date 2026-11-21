import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_bypass.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_strength.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_ui_visible.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_audio_levels.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_pipeline_status.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/update_settings.dart';

class MockAudioEngineRepository extends Mock implements AudioEngineRepository {}

class MockUpdateSettings extends Mock implements UpdateSettings {}

void main() {
  late MockAudioEngineRepository engine;
  late MockUpdateSettings update;

  setUpAll(() {
    registerFallbackValue((ProcessingSettings s) => s);
    registerFallbackValue(SuppressionStrength.medium);
  });

  setUp(() {
    engine = MockAudioEngineRepository();
    update = MockUpdateSettings();
    when(() => update(any())).thenAnswer((_) async => const Ok(unit));
  });

  ProcessingSettings saved() =>
      (verify(() => update(captureAny())).captured.single
          as ProcessingSettings Function(ProcessingSettings))(
        const ProcessingSettings(),
      );

  group('SetBypass', () {
    test('calls the engine and persists userBypass', () async {
      when(() => engine.setBypass(enabled: true)).thenReturn(const Ok(unit));
      expect(await SetBypass(engine, update)(enabled: true), const Ok(unit));
      expect(saved(), const ProcessingSettings(userBypass: true));
    });

    test('engine Err: returned, nothing saved', () async {
      when(
        () => engine.setBypass(enabled: true),
      ).thenReturn(const Err(EngineStateFailure()));
      expect(
        await SetBypass(engine, update)(enabled: true),
        const Err<Unit>(EngineStateFailure()),
      );
      verifyNever(() => update(any()));
    });
  });

  group('SetStrength', () {
    test('calls the engine and persists strength', () async {
      when(() => engine.setStrength(.low)).thenReturn(const Ok(unit));
      expect(await SetStrength(engine, update)(.low), const Ok(unit));
      expect(saved(), const ProcessingSettings(strength: .low));
    });

    test('engine Err: returned, nothing saved', () async {
      when(
        () => engine.setStrength(any()),
      ).thenReturn(const Err(EngineStateFailure()));
      expect(
        await SetStrength(engine, update)(.high),
        const Err<Unit>(EngineStateFailure()),
      );
      verifyNever(() => update(any()));
    });

    test('presets map to the documented maximum reduction', () {
      expect(SuppressionStrength.low.maxAttenuationDb, 12);
      expect(SuppressionStrength.medium.maxAttenuationDb, 24);
      expect(SuppressionStrength.high.maxAttenuationDb, 100);
    });
  });

  test('WatchAudioLevels forwards the repository stream', () async {
    const levels = AudioLevels(inputPeakDb: -12);
    when(() => engine.watchLevels()).thenAnswer((_) => Stream.value(levels));
    expect(await WatchAudioLevels(engine)().toList(), [levels]);
  });

  test('WatchPipelineStatus carries overload bypass through', () async {
    when(() => engine.watchStatus()).thenAnswer(
      (_) => Stream.fromIterable(const [
        PipelineStatus.processing(),
        PipelineStatus.bypassed(.overload),
        PipelineStatus.bypassed(.user),
      ]),
    );
    expect(await WatchPipelineStatus(engine)().toList(), const [
      PipelineStatus.processing(),
      PipelineStatus.bypassed(.overload),
      PipelineStatus.bypassed(.user),
    ]);
  });

  test('SetUiVisible passes the visibility on', () {
    when(
      () => engine.setUiVisible(visible: any(named: 'visible')),
    ).thenReturn(null);
    SetUiVisible(engine)(visible: false);
    verify(() => engine.setUiVisible(visible: false)).called(1);
  });
}
