import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/engine_stats.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';

/// Engine diagnostics for the About page.
@injectable
class GetEngineStats {
  const GetEngineStats(this._engine);

  final AudioEngineRepository _engine;

  Result<EngineStats> call() => _engine.stats();
}
