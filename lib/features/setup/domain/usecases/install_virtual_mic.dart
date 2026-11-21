import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/domain/repositories/setup_repository.dart';

/// Installs the Mute Around virtual microphone (macOS, admin prompt).
@injectable
class InstallVirtualMic {
  const InstallVirtualMic(this._repository);

  final SetupRepository _repository;

  Future<Result<Unit>> call() => _repository.installVirtualMic();
}
