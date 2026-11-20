part of 'pipeline_bloc.dart';

@freezed
abstract class PipelineState with _$PipelineState {
  const factory PipelineState({
    @Default(PipelineStatus.starting()) PipelineStatus status,
  }) = _PipelineState;
}
