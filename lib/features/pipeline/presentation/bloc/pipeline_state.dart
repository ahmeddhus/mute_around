part of 'pipeline_bloc.dart';

@freezed
abstract class PipelineState with _$PipelineState {
  const factory PipelineState({
    @Default(PipelineStatus.starting()) PipelineStatus status,

    /// Microphones to choose from (the selected one included, marked
    /// disconnected, while it's gone).
    @Default(<InputDevice>[]) List<InputDevice> devices,

    /// The microphone the engine is using (or trying to use).
    String? selectedDeviceId,
    @Default(false) bool userBypass,
    @Default(true) bool agcEnabled,
    @Default(SuppressionStrength.medium) SuppressionStrength strength,

    /// Why the last control change (bypass, auto gain, strength, device)
    /// failed, if it did; shown to the user.
    Failure? controlFailure,
  }) = _PipelineState;

  const PipelineState._();

  /// Whether audio is flowing (processed or bypassed), i.e. the controls
  /// have an effect the user can hear right now.
  bool get isActive => status is Processing || status is Bypassed;
}
