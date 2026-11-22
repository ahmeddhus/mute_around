import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/repositories/setup_repository.dart';

/// Asks the OS for microphone access (macOS prompt).
@injectable
class RequestMicPermission {
  const RequestMicPermission(this._repository);

  final SetupRepository _repository;

  Future<Result<MicPermission>> call() => _repository.requestMicPermission();
}
