part of 'pipeline_bloc.dart';

@freezed
sealed class PipelineEvent with _$PipelineEvent {
  /// Setup readiness changed (virtual mic + permission). Processing starts
  /// on the first `ready: true`; `ready: false` stops it.
  const factory PipelineEvent.readinessChanged({required bool ready}) =
      ReadinessChanged;

  /// The engine reported a new status (internal). A lost microphone arrives
  /// here as `DeviceDisconnected`.
  const factory PipelineEvent.engineStatusChanged(PipelineStatus status) =
      EngineStatusChanged;

  /// The user asked to try starting again after an error.
  const factory PipelineEvent.retryRequested() = RetryRequested;

  /// A poll of the microphone list (internal, every 2 s).
  const factory PipelineEvent.devicesChanged(InputDeviceSnapshot snapshot) =
      DevicesChanged;

  /// The user picked a microphone.
  const factory PipelineEvent.inputSelected(String deviceId) = InputSelected;

  /// The user turned automatic gain on or off.
  const factory PipelineEvent.agcToggled({required bool enabled}) = AgcToggled;

  /// The user turned bypass on or off.
  const factory PipelineEvent.bypassToggled({required bool enabled}) =
      BypassToggled;

  /// The user picked a noise-suppression preset.
  const factory PipelineEvent.strengthChanged(SuppressionStrength strength) =
      StrengthChanged;
}
