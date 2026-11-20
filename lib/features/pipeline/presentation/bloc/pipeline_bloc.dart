import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/usecases/start_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/stop_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_pipeline_status.dart';

part 'pipeline_bloc.freezed.dart';
part 'pipeline_event.dart';
part 'pipeline_state.dart';

/// Runs the voice pipeline for the whole app lifetime (app-scoped).
/// Processing starts automatically once setup
/// is ready, not when the bloc is created.
@injectable
class PipelineBloc extends Bloc<PipelineEvent, PipelineState> {
  PipelineBloc(this._startPipeline, this._stopPipeline, this._watchStatus)
    : super(const PipelineState()) {
    on<ReadinessChanged>(_onReadinessChanged);
    on<RetryRequested>((_, emit) => _start(emit));
    on<EngineStatusChanged>(
      (event, emit) => emit(state.copyWith(status: event.status)),
    );
  }

  final StartPipeline _startPipeline;
  final StopPipeline _stopPipeline;
  final WatchPipelineStatus _watchStatus;

  StreamSubscription<PipelineStatus>? _statusSubscription;
  bool _running = false;
  bool _starting = false;

  Future<void> _onReadinessChanged(
    ReadinessChanged event,
    Emitter<PipelineState> emit,
  ) async {
    if (event.ready) return _start(emit);
    if (_running) {
      _running = false;
      await _stopPipeline();
    }
    emit(state.copyWith(status: const PipelineStatus.setupRequired()));
  }

  Future<void> _start(Emitter<PipelineState> emit) async {
    if (_running || _starting) return;
    _starting = true;
    emit(state.copyWith(status: const PipelineStatus.starting()));
    final result = await _startPipeline();
    _starting = false;
    switch (result) {
      case Ok():
        _running = true;
        emit(state.copyWith(status: const PipelineStatus.processing()));
        _statusSubscription ??= _watchStatus().listen(
          (status) => add(PipelineEvent.engineStatusChanged(status)),
        );
      case Err(:final failure):
        emit(state.copyWith(status: _statusFor(failure)));
    }
  }

  static PipelineStatus _statusFor(Failure failure) => switch (failure) {
    VirtualMicMissing() => PipelineStatus.setupRequired(failure),
    PermissionDenied() => const PipelineStatus.permissionNeeded(),
    DeviceNotFound() => const PipelineStatus.noInputDevice(),
    _ => PipelineStatus.engineError(failure),
  };

  @override
  Future<void> close() async {
    await _statusSubscription?.cancel();
    return super.close();
  }
}
