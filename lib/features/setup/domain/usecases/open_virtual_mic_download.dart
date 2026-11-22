import 'package:injectable/injectable.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/domain/repositories/setup_repository.dart';

/// Opens the VB-CABLE download page in the user's browser (Windows).
@injectable
class OpenVirtualMicDownload {
  const OpenVirtualMicDownload(this._repository);

  final SetupRepository _repository;

  Future<Result<Unit>> call() => _repository.openVirtualMicDownload();
}
