import 'package:injectable/injectable.dart';
import 'package:mute_around/core/native/macos_permissions.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';

/// Microphone permission, per platform.
abstract interface class PermissionDataSource {
  Future<MicPermission> status();

  /// Shows the OS prompt if possible (macOS) and returns the result.
  Future<MicPermission> request();

  /// Records an "access denied" reported by the engine (Windows).
  void markDenied();

  /// Forgets [markDenied].
  void clearDenied();
}

/// macOS: `AVCaptureDevice` through ffigen Objective-C interop. Windows has
/// no query API: `notDetermined` until the engine reports a denial.
@LazySingleton(as: PermissionDataSource)
class PlatformPermissionDataSource implements PermissionDataSource {
  PlatformPermissionDataSource(this._host, {@ignoreParam this.macos});

  final HostInfo _host;

  /// Injected in tests; defaults to [MacosPermissions.instance] on macOS.
  final MacosPermissions? macos;

  bool _reportedDenied = false;

  MacosPermissions get _macos => macos ?? MacosPermissions.instance;

  @override
  Future<MicPermission> status() async {
    if (_reportedDenied) return .denied;
    return switch (_host.platform) {
      .macos => _fromMacos(_macos.status()),
      .windows => .notDetermined,
    };
  }

  @override
  Future<MicPermission> request() async => switch (_host.platform) {
    .macos => _fromMacos(await _macos.request()),
    // Windows asks (or doesn't) when the microphone is opened.
    .windows => status(),
  };

  @override
  void markDenied() => _reportedDenied = true;

  @override
  void clearDenied() => _reportedDenied = false;

  static MicPermission _fromMacos(MacosMicAuthorization a) => switch (a) {
    .authorized => .granted,
    // Restricted (parental controls / MDM) can't be granted by the user
    // either; the setup screen shows the same instructions.
    .denied || .restricted => .denied,
    .notDetermined => .notDetermined,
  };
}
