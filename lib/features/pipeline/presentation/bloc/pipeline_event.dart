part of 'pipeline_bloc.dart';

@freezed
sealed class PipelineEvent with _$PipelineEvent {
  /// Setup readiness changed (virtual mic + permission). Processing starts
  /// on the first `ready: true`; `ready: false` stops it.
  const factory PipelineEvent.readinessChanged({required bool ready}) =
      ReadinessChanged;

  /// The engine reported a new status (internal).
  const factory PipelineEvent.engineStatusChanged(PipelineStatus status) =
      EngineStatusChanged;

  /// The user asked to try starting again after an error.
  const factory PipelineEvent.retryRequested() = RetryRequested;
}
