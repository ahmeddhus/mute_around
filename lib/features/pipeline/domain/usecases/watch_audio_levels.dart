import 'package:injectable/injectable.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';

/// Input and output levels for the meters, at most 30 per second.
@injectable
class WatchAudioLevels {
  const WatchAudioLevels(this._engine);

  final AudioEngineRepository _engine;

  Stream<AudioLevels> call() => _engine.watchLevels();
}
