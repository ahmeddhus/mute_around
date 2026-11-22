import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';

/// Stops processing; the virtual mic goes silent.
@injectable
class StopPipeline {
  const StopPipeline(this._engine);

  final AudioEngineRepository _engine;

  Future<Result<Unit>> call() => _engine.stop();
}
