import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/settings/domain/usecases/update_settings.dart';

/// Turns automatic gain on or off and remembers it.
///
/// The engine applies it at the next 10 ms frame; nothing is saved if the
/// engine call fails.
@injectable
class SetAgcEnabled {
  const SetAgcEnabled(this._engine, this._updateSettings);

  final AudioEngineRepository _engine;
  final UpdateSettings _updateSettings;

  Future<Result<Unit>> call({required bool enabled}) async {
    final applied = _engine.setAgc(enabled: enabled);
    if (applied case Err()) return applied;
    return _updateSettings((s) => s.copyWith(agcEnabled: enabled));
  }
}
