import 'package:injectable/injectable.dart';
import 'package:mute_around/features/settings/domain/repositories/settings_repository.dart';

/// Writes any debounced settings changes now, e.g. right before the app
/// quits, so a change made in the last moments isn't lost.
@injectable
class FlushSettings {
  const FlushSettings(this._repository);

  final SettingsRepository _repository;

  Future<void> call() => _repository.flush();
}
