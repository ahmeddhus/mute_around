import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/settings/domain/usecases/update_settings.dart';

/// Switches to another microphone while processing runs and
/// remembers it. Nothing is saved if the switch fails.
///
/// [remember] is `false` for automatic recovery (the chosen microphone came
/// back, a fallback after there was none): the user's saved choice stays.
@injectable
class SelectInputDevice {
  const SelectInputDevice(this._engine, this._updateSettings);

  final AudioEngineRepository _engine;
  final UpdateSettings _updateSettings;

  Future<Result<Unit>> call(String deviceId, {bool remember = true}) async {
    final switched = await _engine.switchInput(deviceId);
    if (switched case Err()) return switched;
    if (!remember) return switched;
    return _updateSettings((s) => s.copyWith(inputDeviceId: deviceId));
  }
}
