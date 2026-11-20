import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:mute_around/core/audio/audio_device.dart';
import 'package:mute_around/core/audio/virtual_mic_locator.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/data/datasources/engine_data_source.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

@LazySingleton(as: AudioEngineRepository)
class AudioEngineRepositoryImpl implements AudioEngineRepository {
  AudioEngineRepositoryImpl(this._engine, this._host);

  final EngineDataSource _engine;
  final HostInfo _host;
  String? _currentInputId;

  @override
  Future<Result<List<InputDevice>>> listInputDevices() async =>
      switch (_engine.listDevices(.capture)) {
        Ok(:final value) => Ok([
          for (final d in value)
            if (!isOwnVirtualMicInput(d.id, d.name, _host.platform))
              InputDevice(id: d.id, name: d.name, isDefault: d.isDefault),
        ]),
        Err(:final failure) => Err(failure),
      };

  @override
  Future<Result<Unit>> start({String? inputDeviceId}) async {
    final AudioDevice? sink;
    switch (_engine.listDevices(.playback)) {
      case Ok(:final value):
        sink = findVirtualMicSink(value, _host.platform);
      case Err(:final failure):
        return Err(failure);
    }
    if (sink == null) {
      return Err(
        VirtualMicMissing(switch (_host.platform) {
          .macos => 'The Mute Around microphone is not installed',
          .windows => 'VB-CABLE is not installed',
        }),
      );
    }
    final result = _engine.start(captureId: inputDeviceId, sinkId: sink.id);
    if (result.isOk) _currentInputId = inputDeviceId;
    return result;
  }

  @override
  Future<Result<Unit>> stop() async => _engine.stop();

  @override
  Result<Unit> setBypass({required bool enabled}) =>
      _engine.setBypass(enabled: enabled);

  @override
  Result<Unit> setAgc({required bool enabled}) =>
      _engine.setAgc(enabled: enabled);

  @override
  Result<Unit> setStrength(SuppressionStrength strength) =>
      _engine.setStrength(strength);

  @override
  Stream<PipelineStatus> watchStatus() => _engine.status
      .map(_toDomain)
      .where((s) => s != null)
      .cast<PipelineStatus>();

  @override
  void setUiVisible({required bool visible}) =>
      _engine.setVisible(visible: visible);

  PipelineStatus? _toDomain(EngineStatus status) => switch (status) {
    // Stopped is not reported: the bloc knows why it stopped.
    .stopped => null,
    .running => const PipelineStatus.processing(),
    .bypassedUser => const PipelineStatus.bypassed(.user),
    .bypassedOverload => const PipelineStatus.bypassed(.overload),
    .deviceDisconnected => PipelineStatus.deviceDisconnected(_currentInputId),
    .error => const PipelineStatus.engineError(
      UnknownFailure('The audio engine reported an error'),
    ),
  };
}
