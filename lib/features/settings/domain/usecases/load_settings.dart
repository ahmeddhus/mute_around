import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/repositories/settings_repository.dart';

/// Loads the user's [ProcessingSettings].
@injectable
class LoadSettings {
  const LoadSettings(this._repository);

  final SettingsRepository _repository;

  Future<Result<ProcessingSettings>> call() => _repository.load();
}
