import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/pipeline/domain/usecases/select_input_device.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/update_settings.dart';

class MockAudioEngineRepository extends Mock implements AudioEngineRepository {}

class MockUpdateSettings extends Mock implements UpdateSettings {}

void main() {
  late MockAudioEngineRepository engine;
  late MockUpdateSettings update;
  late SelectInputDevice select;

  setUpAll(() => registerFallbackValue((ProcessingSettings s) => s));

  setUp(() {
    engine = MockAudioEngineRepository();
    update = MockUpdateSettings();
    select = SelectInputDevice(engine, update);
    when(() => update(any())).thenAnswer((_) async => const Ok(unit));
  });

  test('switch succeeds → persists the device id', () async {
    when(
      () => engine.switchInput('usb'),
    ).thenAnswer((_) async => const Ok(unit));
    expect(await select('usb'), const Ok(unit));
    final change =
        verify(() => update(captureAny())).captured.single
            as ProcessingSettings Function(ProcessingSettings);
    expect(
      change(const ProcessingSettings(strength: .low)),
      const ProcessingSettings(strength: .low, inputDeviceId: 'usb'),
    );
  });

  test('switch fails → Err, nothing persisted', () async {
    when(
      () => engine.switchInput('usb'),
    ).thenAnswer((_) async => const Err(DeviceNotFound('gone')));
    expect(await select('usb'), const Err<Unit>(DeviceNotFound('gone')));
    verifyNever(() => update(any()));
  });

  test('remember: false switches without persisting', () async {
    when(
      () => engine.switchInput('usb'),
    ).thenAnswer((_) async => const Ok(unit));
    expect(await select('usb', remember: false), const Ok(unit));
    verifyNever(() => update(any()));
  });

  test('a failed save is returned', () async {
    when(
      () => engine.switchInput('usb'),
    ).thenAnswer((_) async => const Ok(unit));
    when(
      () => update(any()),
    ).thenAnswer((_) async => const Err(UnknownFailure('disk')));
    expect(await select('usb'), const Err<Unit>(UnknownFailure('disk')));
  });
}
