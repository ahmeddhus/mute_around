import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';
import 'package:mute_around/features/settings/domain/repositories/settings_repository.dart';

/// Changes one or more stored settings: applies [change] to the current
/// ones and saves the result (debounced by the repository).
///
/// Shared by the pipeline use cases that persist a single choice (device,
/// bypass, auto gain, strength).
@injectable
class UpdateSettings {
  const UpdateSettings(this._repository);

  final SettingsRepository _repository;

  Future<Result<Unit>> call(
    ProcessingSettings Function(ProcessingSettings current) change,
  ) => _repository.update(change);
}
