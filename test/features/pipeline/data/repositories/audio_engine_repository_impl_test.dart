import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/audio/audio_device.dart';
import 'package:mute_around/core/audio/virtual_mic_locator.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/data/datasources/engine_data_source.dart';
import 'package:mute_around/features/pipeline/data/repositories/audio_engine_repository_impl.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

class MockEngineDataSource extends Mock implements EngineDataSource {}

void main() {
  late MockEngineDataSource engine;

  const builtIn = AudioDevice(
    id: 'BuiltIn',
    name: 'MacBook Mic',
    isDefault: true,
  );
  const usb = AudioDevice(id: 'usb-123', name: 'USB Mic');
  const ownMac = AudioDevice(id: virtualMicUid, name: 'Mute Around');
  const cableOut = AudioDevice(
    id: 'w1',
    name: 'CABLE Output (VB-Audio Virtual Cable)',
  );
  const cableIn = AudioDevice(
    id: 'w2',
    name: 'CABLE Input (VB-Audio Virtual Cable)',
  );
  const speakers = AudioDevice(id: 'spk', name: 'Speakers', isDefault: true);

  AudioEngineRepositoryImpl repo(HostPlatform platform) =>
      AudioEngineRepositoryImpl(engine, HostInfo(platform));

  setUpAll(() => registerFallbackValue(SuppressionStrength.medium));
  setUp(() => engine = MockEngineDataSource());

  group('listInputDevices', () {
    test('macOS: filters out the own virtual mic', () async {
      when(() => engine.listDevices(.capture))
          .thenReturn(const Ok([builtIn, ownMac, usb]));
      final result = await repo(.macos).listInputDevices();
      expect(result.valueOrNull, [
        InputDevice(id: 'BuiltIn', name: 'x'),
        InputDevice(id: 'usb-123', name: 'x'),
      ]);
      expect(result.valueOrNull!.first.isDefault, isTrue);
    });

    test('Windows: filters out CABLE Output', () async {
      when(() => engine.listDevices(.capture))
          .thenReturn(const Ok([usb, cableOut]));
      final result = await repo(.windows).listInputDevices();
      expect(result.valueOrNull!.map((d) => d.id), ['usb-123']);
    });

    test('propagates datasource errors', () async {
      when(() => engine.listDevices(.capture))
          .thenReturn(const Err(DeviceFailure('x')));
      expect(
        await repo(.macos).listInputDevices(),
        const Err<List<InputDevice>>(DeviceFailure('x')),
      );
    });
  });

  group('start', () {
    test('macOS: plays into the Mute Around device', () async {
      when(() => engine.listDevices(.playback))
          .thenReturn(const Ok([speakers, ownMac]));
      when(
        () => engine.start(
          captureId: any(named: 'captureId'),
          sinkId: any(named: 'sinkId'),
        ),
      ).thenReturn(const Ok(unit));
      expect(
        await repo(.macos).start(inputDeviceId: 'usb-123'),
        const Ok(unit),
      );
      verify(() => engine.start(captureId: 'usb-123', sinkId: virtualMicUid))
          .called(1);
    });

    test('Windows: plays into CABLE Input', () async {
      when(() => engine.listDevices(.playback))
          .thenReturn(const Ok([speakers, cableIn]));
      when(
        () => engine.start(
          captureId: any(named: 'captureId'),
          sinkId: any(named: 'sinkId'),
        ),
      ).thenReturn(const Ok(unit));
      expect(await repo(.windows).start(), const Ok(unit));
      verify(() => engine.start(sinkId: 'w2')).called(1);
    });

    test('no sink → VirtualMicMissing, engine not started', () async {
      when(() => engine.listDevices(.playback))
          .thenReturn(const Ok([speakers]));
      final result = await repo(.macos).start();
      expect(result.failureOrNull, isA<VirtualMicMissing>());
      verifyNever(
        () => engine.start(
          captureId: any(named: 'captureId'),
          sinkId: any(named: 'sinkId'),
        ),
      );
    });

    for (final failure in const <Failure>[
      PermissionDenied(),
      DeviceNotFound(),
      DeviceFailure(),
      ModelLoadFailure(),
      EngineStateFailure(),
    ]) {
      test('passes through ${failure.runtimeType}', () async {
        when(() => engine.listDevices(.playback))
            .thenReturn(const Ok([ownMac]));
        when(
          () => engine.start(
            captureId: any(named: 'captureId'),
            sinkId: any(named: 'sinkId'),
          ),
        ).thenReturn(Err(failure));
        expect(await repo(.macos).start(), Err<Unit>(failure));
      });
    }
  });

  test('stop and setters pass through', () async {
    when(() => engine.stop()).thenReturn(const Ok(unit));
    when(() => engine.setBypass(enabled: any(named: 'enabled')))
        .thenReturn(const Ok(unit));
    when(() => engine.setAgc(enabled: any(named: 'enabled')))
        .thenReturn(const Ok(unit));
    when(() => engine.setStrength(any())).thenReturn(const Ok(unit));
    final r = repo(.macos);
    expect(await r.stop(), const Ok(unit));
    expect(r.setBypass(enabled: true), const Ok(unit));
    expect(r.setAgc(enabled: false), const Ok(unit));
    expect(r.setStrength(.high), const Ok(unit));
    verify(() => engine.setBypass(enabled: true)).called(1);
    verify(() => engine.setAgc(enabled: false)).called(1);
    verify(() => engine.setStrength(.high)).called(1);
  });

  test('watchStatus maps engine status and skips stopped', () async {
    final controller = StreamController<EngineStatus>();
    addTearDown(controller.close);
    when(() => engine.status).thenAnswer((_) => controller.stream);
    when(() => engine.listDevices(.playback)).thenReturn(const Ok([ownMac]));
    when(
      () => engine.start(
        captureId: any(named: 'captureId'),
        sinkId: any(named: 'sinkId'),
      ),
    ).thenReturn(const Ok(unit));
    final r = repo(.macos);
    await r.start(inputDeviceId: 'usb-123');

    final statuses = r.watchStatus().take(5).toList();
    for (final s in [
      EngineStatus.stopped,
      EngineStatus.running,
      EngineStatus.bypassedUser,
      EngineStatus.bypassedOverload,
      EngineStatus.deviceDisconnected,
      EngineStatus.error,
    ]) {
      controller.add(s);
    }
    expect(await statuses, [
      const PipelineStatus.processing(),
      const PipelineStatus.bypassed(.user),
      const PipelineStatus.bypassed(.overload),
      const PipelineStatus.deviceDisconnected('usb-123'),
      isA<EngineError>(),
    ]);
  });
}
