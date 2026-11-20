import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/pipeline/domain/usecases/start_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/stop_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_pipeline_status.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/load_settings.dart';

class MockAudioEngineRepository extends Mock implements AudioEngineRepository {}

class MockLoadSettings extends Mock implements LoadSettings {}

void main() {
  late MockAudioEngineRepository engine;
  late MockLoadSettings loadSettings;
  late StartPipeline startPipeline;
  final calls = <String>[];

  final builtIn = InputDevice(
    id: 'BuiltIn',
    name: 'MacBook Mic',
    isDefault: true,
  );
  final usb = InputDevice(id: 'usb', name: 'USB Mic');

  setUpAll(() => registerFallbackValue(SuppressionStrength.medium));

  setUp(() {
    calls.clear();
    engine = MockAudioEngineRepository();
    loadSettings = MockLoadSettings();
    startPipeline = StartPipeline(engine, loadSettings);
    when(() => engine.listInputDevices())
        .thenAnswer((_) async => Ok([builtIn, usb]));
    when(() => engine.setStrength(any())).thenAnswer((i) {
      calls.add(
        'strength ${(i.positionalArguments.first as SuppressionStrength).name}',
      );
      return const Ok(unit);
    });
    when(() => engine.setAgc(enabled: any(named: 'enabled'))).thenAnswer((i) {
      calls.add('agc ${i.namedArguments[#enabled]}');
      return const Ok(unit);
    });
    when(() => engine.setBypass(enabled: any(named: 'enabled')))
        .thenAnswer((i) {
          calls.add('bypass ${i.namedArguments[#enabled]}');
          return const Ok(unit);
        });
    when(() => engine.start(inputDeviceId: any(named: 'inputDeviceId')))
        .thenAnswer((i) async {
          calls.add('start ${i.namedArguments[#inputDeviceId]}');
          return const Ok(unit);
        });
  });

  void givenSettings(ProcessingSettings s) =>
      when(() => loadSettings()).thenAnswer((_) async => Ok(s));

  group('StartPipeline', () {
    test('uses the stored device and applies settings before start', () async {
      givenSettings(
        const ProcessingSettings(
          inputDeviceId: 'usb',
          strength: .high,
          agcEnabled: false,
          userBypass: true,
        ),
      );
      expect(await startPipeline(), const Ok(unit));
      expect(calls, ['strength high', 'agc false', 'bypass true', 'start usb']);
    });

    test(
      'falls back to the OS default when the stored device is gone',
      () async {
        givenSettings(const ProcessingSettings(inputDeviceId: 'unplugged'));
        expect(await startPipeline(), const Ok(unit));
        expect(calls.last, 'start null');
      },
    );

    test('uses defaults when settings cannot be read', () async {
      when(() => loadSettings())
          .thenAnswer((_) async => const Err(UnknownFailure()));
      expect(await startPipeline(), const Ok(unit));
      expect(calls, [
        'strength medium',
        'agc true',
        'bypass false',
        'start null',
      ]);
    });

    test('no microphones → DeviceNotFound, engine not started', () async {
      givenSettings(const ProcessingSettings());
      when(() => engine.listInputDevices())
          .thenAnswer((_) async => const Ok([]));
      expect((await startPipeline()).failureOrNull, isA<DeviceNotFound>());
      verifyNever(
        () => engine.start(inputDeviceId: any(named: 'inputDeviceId')),
      );
    });

    test('missing sink → VirtualMicMissing from the repository', () async {
      givenSettings(const ProcessingSettings());
      when(() => engine.start(inputDeviceId: any(named: 'inputDeviceId')))
          .thenAnswer((_) async => const Err(VirtualMicMissing()));
      expect(await startPipeline(), const Err<Unit>(VirtualMicMissing()));
    });

    test('a failing setter aborts before start', () async {
      givenSettings(const ProcessingSettings());
      when(() => engine.setStrength(any()))
          .thenReturn(const Err(ModelLoadFailure()));
      expect(await startPipeline(), const Err<Unit>(ModelLoadFailure()));
      verifyNever(
        () => engine.start(inputDeviceId: any(named: 'inputDeviceId')),
      );
    });
  });

  test('StopPipeline stops the engine', () async {
    when(() => engine.stop()).thenAnswer((_) async => const Ok(unit));
    expect(await StopPipeline(engine)(), const Ok(unit));
    verify(() => engine.stop()).called(1);
  });

  test('WatchPipelineStatus forwards the repository stream', () async {
    when(() => engine.watchStatus())
        .thenAnswer((_) => Stream.value(const PipelineStatus.processing()));
    expect(await WatchPipelineStatus(engine)().toList(), [
      const PipelineStatus.processing(),
    ]);
  });
}
