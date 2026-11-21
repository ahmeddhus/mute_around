import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device_snapshot.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/usecases/select_input_device.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_agc_enabled.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_bypass.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_strength.dart';
import 'package:mute_around/features/pipeline/domain/usecases/start_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/stop_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_input_devices.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/load_settings.dart';
import 'package:mute_around/features/settings/domain/usecases/update_settings.dart';

class MockStartPipeline extends Mock implements StartPipeline {}

class MockStopPipeline extends Mock implements StopPipeline {}

class MockWatchPipelineStatus extends Mock implements WatchPipelineStatus {}

class MockLoadSettings extends Mock implements LoadSettings {}

class MockUpdateSettings extends Mock implements UpdateSettings {}

class MockWatchInputDevices extends Mock implements WatchInputDevices {}

class MockSelectInputDevice extends Mock implements SelectInputDevice {}

class MockSetAgcEnabled extends Mock implements SetAgcEnabled {}

class MockSetBypass extends Mock implements SetBypass {}

class MockSetStrength extends Mock implements SetStrength {}

/// Mocked use cases for [PipelineBloc] tests, all succeeding by default:
/// settings are [settings], start uses [startedWith], and the engine status
/// and device polls are driven through [engineStatus] and [devices].
class PipelineHarness {
  PipelineHarness() {
    registerFallbackValue(SuppressionStrength.medium);
    registerFallbackValue(Duration.zero);
    registerFallbackValue((ProcessingSettings s) => s);
    when(start.call).thenAnswer((_) async => Ok(startedWith));
    when(stop.call).thenAnswer((_) async => const Ok(unit));
    when(watchStatus.call).thenAnswer((_) => engineStatus.stream);
    when(loadSettings.call).thenAnswer((_) async => Ok(settings));
    when(() => updateSettings(any())).thenAnswer((_) async => const Ok(unit));
    when(
      () => watchDevices(
        selectedId: any(named: 'selectedId'),
        interval: any(named: 'interval'),
      ),
    ).thenAnswer((_) => devices.stream);
    when(
      () => selectDevice(any(), remember: any(named: 'remember')),
    ).thenAnswer((_) async => const Ok(unit));
    when(
      () => setAgc(enabled: any(named: 'enabled')),
    ).thenAnswer((_) async => const Ok(unit));
    when(
      () => setBypass(enabled: any(named: 'enabled')),
    ).thenAnswer((_) async => const Ok(unit));
    when(() => setStrength(any())).thenAnswer((_) async => const Ok(unit));
  }

  final start = MockStartPipeline();
  final stop = MockStopPipeline();
  final watchStatus = MockWatchPipelineStatus();
  final loadSettings = MockLoadSettings();
  final updateSettings = MockUpdateSettings();
  final watchDevices = MockWatchInputDevices();
  final selectDevice = MockSelectInputDevice();
  final setAgc = MockSetAgcEnabled();
  final setBypass = MockSetBypass();
  final setStrength = MockSetStrength();

  final engineStatus = StreamController<PipelineStatus>.broadcast();
  final devices = StreamController<InputDeviceSnapshot>.broadcast();

  ProcessingSettings settings = const ProcessingSettings();
  String startedWith = 'builtin';

  PipelineBloc build() => PipelineBloc(
    PipelineUseCases(
      start: start,
      stop: stop,
      watchStatus: watchStatus,
      loadSettings: loadSettings,
      updateSettings: updateSettings,
      watchDevices: watchDevices,
      selectDevice: selectDevice,
      setAgc: setAgc,
      setBypass: setBypass,
      setStrength: setStrength,
    ),
  );

  Future<void> dispose() async {
    await engineStatus.close();
    await devices.close();
  }
}

/// Lets queued events and stream deliveries run.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// Starts [bloc] as the app does once setup is ready.
Future<void> startReady(PipelineBloc bloc) async {
  bloc.add(const PipelineEvent.readinessChanged(ready: true));
  await settle();
}

/// Matches a [PipelineState] whose status equals [status].
Matcher hasStatus(PipelineStatus status) =>
    isA<PipelineState>().having((s) => s.status, 'status', status);

/// A device poll with [connected] microphones (plus [disconnected] ones).
InputDeviceSnapshot snapshot(
  List<String> connected, {
  List<String> disconnected = const [],
  Set<String> added = const {},
  Set<String> removed = const {},
}) => InputDeviceSnapshot(
  devices: [
    for (final id in connected) InputDevice(id: id, name: id),
    for (final id in disconnected)
      InputDevice(id: id, name: id, isConnected: false),
  ],
  added: added,
  removed: removed,
);
