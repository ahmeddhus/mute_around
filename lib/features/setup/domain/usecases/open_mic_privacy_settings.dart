import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/domain/repositories/setup_repository.dart';

/// Opens the OS microphone privacy settings.
@injectable
class OpenMicPrivacySettings {
  const OpenMicPrivacySettings(this._repository);

  final SetupRepository _repository;

  Future<Result<Unit>> call() => _repository.openMicPrivacySettings();
}
