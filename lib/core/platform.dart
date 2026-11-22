import 'dart:io' show Platform;

/// The desktop platforms Mute Around supports.
enum HostPlatform { macos, windows }

/// Detects the host platform. Only macOS and Windows are supported; any
/// other OS is a programming error.
HostPlatform currentHostPlatform() {
  return switch (Platform.operatingSystem) {
    'macos' => .macos,
    'windows' => .windows,
    _ => throw UnsupportedError('Mute Around supports macOS and Windows only'),
  };
}

/// Injectable holder for the [HostPlatform] (injectable can't register enums).
final class HostInfo {
  const HostInfo(this.platform);

  final HostPlatform platform;
}
