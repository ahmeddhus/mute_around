import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_agc_enabled.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/update_settings.dart';

class MockAudioEngineRepository extends Mock implements AudioEngineRepository {}

class MockUpdateSettings extends Mock implements UpdateSettings {}

void main() {
  late MockAudioEngineRepository engine;
  late MockUpdateSettings update;

  setUpAll(() => registerFallbackValue((ProcessingSettings s) => s));

  setUp(() {
    engine = MockAudioEngineRepository();
    update = MockUpdateSettings();
    when(() => update(any())).thenAnswer((_) async => const Ok(unit));
  });

  test('calls the engine, then persists agcEnabled', () async {
    when(() => engine.setAgc(enabled: false)).thenReturn(const Ok(unit));
    expect(await SetAgcEnabled(engine, update)(enabled: false), const Ok(unit));
    verify(() => engine.setAgc(enabled: false)).called(1);
    final change =
        verify(() => update(captureAny())).captured.single
            as ProcessingSettings Function(ProcessingSettings);
    expect(
      change(const ProcessingSettings()),
      const ProcessingSettings(agcEnabled: false),
    );
  });

  test('engine Err is propagated and nothing is saved', () async {
    when(
      () => engine.setAgc(enabled: true),
    ).thenReturn(const Err(EngineStateFailure()));
    expect(
      await SetAgcEnabled(engine, update)(enabled: true),
      const Err<Unit>(EngineStateFailure()),
    );
    verifyNever(() => update(any()));
  });

  test('a save Err is propagated', () async {
    when(() => engine.setAgc(enabled: true)).thenReturn(const Ok(unit));
    when(
      () => update(any()),
    ).thenAnswer((_) async => const Err(UnknownFailure('disk')));
    expect(
      await SetAgcEnabled(engine, update)(enabled: true),
      const Err<Unit>(UnknownFailure('disk')),
    );
  });
}
