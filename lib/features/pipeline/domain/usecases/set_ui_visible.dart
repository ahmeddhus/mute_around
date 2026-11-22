import 'package:injectable/injectable.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';

/// Tells the engine whether the window is visible: status is polled at
/// 30 Hz while it is and 4 Hz while hidden in the tray, and the meters
/// pause.
@injectable
class SetUiVisible {
  const SetUiVisible(this._engine);

  final AudioEngineRepository _engine;

  void call({required bool visible}) => _engine.setUiVisible(visible: visible);
}
