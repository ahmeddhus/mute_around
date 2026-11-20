import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:mute_around/core/failures.dart';

part 'pipeline_status.freezed.dart';

/// Why processing is bypassed.
enum BypassReason {
  /// The user turned bypass on.
  user,

  /// The computer couldn't keep up, so raw audio is passed.
  overload,
}

/// What the voice pipeline is doing.
@freezed
sealed class PipelineStatus with _$PipelineStatus {
  /// The virtual microphone is missing; [failure] says why, if known.
  const factory PipelineStatus.setupRequired([Failure? failure]) =
      SetupRequired;

  /// The OS refused microphone access.
  const factory PipelineStatus.permissionNeeded() = PermissionNeeded;

  const factory PipelineStatus.starting() = Starting;

  const factory PipelineStatus.processing() = Processing;

  const factory PipelineStatus.bypassed(BypassReason reason) = Bypassed;

  /// The selected microphone went away; the virtual mic gets silence.
  const factory PipelineStatus.deviceDisconnected(String? deviceId) =
      DeviceDisconnected;

  /// No microphone is connected at all.
  const factory PipelineStatus.noInputDevice() = NoInputDevice;

  const factory PipelineStatus.engineError(Failure failure) = EngineError;
}
