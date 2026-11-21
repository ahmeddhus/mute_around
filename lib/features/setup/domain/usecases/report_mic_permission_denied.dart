import 'package:injectable/injectable.dart';
import 'package:mute_around/features/setup/domain/repositories/setup_repository.dart';

/// Records that the engine was refused microphone access (Windows learns
/// about a denial only this way).
@injectable
class ReportMicPermissionDenied {
  const ReportMicPermissionDenied(this._repository);

  final SetupRepository _repository;

  void call() => _repository.reportMicPermissionDenied();
}
