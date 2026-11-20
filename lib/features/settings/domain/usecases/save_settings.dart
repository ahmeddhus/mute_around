import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/repositories/settings_repository.dart';

/// Saves the user's [ProcessingSettings].
@injectable
class SaveSettings {
  const SaveSettings(this._repository);

  final SettingsRepository _repository;

  Future<Result<Unit>> call(ProcessingSettings settings) =>
      _repository.save(settings);
}
