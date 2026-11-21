import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';

/// Checks and fixes what processing needs: the virtual mic and microphone
/// permission.
abstract interface class SetupRepository {
  /// Looks for the virtual-mic sink among the playback devices.
  Future<VirtualMicStatus> virtualMicStatus();

  Future<MicPermission> micPermission();

  /// Shows the OS permission prompt if the user hasn't decided yet (macOS);
  /// returns the resulting permission.
  Future<Result<MicPermission>> requestMicPermission();

  /// Installs the Mute Around plug-in (macOS; asks for an administrator
  /// password). `Err(UserCancelled)` if the user cancels the prompt.
  Future<Result<Unit>> installVirtualMic();

  /// Opens the OS microphone privacy settings.
  Future<Result<Unit>> openMicPrivacySettings();

  /// Opens the VB-CABLE download page in the browser (Windows).
  Future<Result<Unit>> openVirtualMicDownload();

  /// Records that the OS refused microphone access when the engine tried to
  /// open it (how Windows learns about a denial).
  void reportMicPermissionDenied();

  /// Forgets a denial recorded by [reportMicPermissionDenied], so the next
  /// start tries again (after the user may have changed the setting).
  void clearReportedDenial();
}
