import 'package:injectable/injectable.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';

/// The engine's status while it runs, emitted on change.
@injectable
class WatchPipelineStatus {
  const WatchPipelineStatus(this._engine);

  final AudioEngineRepository _engine;

  Stream<PipelineStatus> call() => _engine.watchStatus();
}
