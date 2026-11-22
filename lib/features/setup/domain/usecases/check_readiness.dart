import 'package:injectable/injectable.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/setup/domain/entities/readiness.dart';
import 'package:mute_around/features/setup/domain/repositories/setup_repository.dart';

/// Checks the virtual mic and microphone permission.
@injectable
class CheckReadiness {
  const CheckReadiness(this._repository, this._host);

  final SetupRepository _repository;
  final HostInfo _host;

  /// [retryDenied]: forget a denial the engine reported earlier, so the
  /// next start tries the microphone again. Pass it when the user may have
  /// changed the setting (they came back to the app or pressed "Check
  /// again"), not on automatic checks.
  Future<Readiness> call({bool retryDenied = false}) async {
    if (retryDenied) _repository.clearReportedDenial();
    return Readiness(
      platform: _host.platform,
      virtualMic: await _repository.virtualMicStatus(),
      permission: await _repository.micPermission(),
    );
  }
}
