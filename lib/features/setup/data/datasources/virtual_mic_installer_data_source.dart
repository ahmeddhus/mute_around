import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';

/// Runs a process; injectable so tests don't spawn anything.
typedef RunProcess = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Installs the virtual microphone.
abstract interface class VirtualMicInstallerDataSource {
  Future<Result<Unit>> install();
}

/// Installs the bundled `MuteAround.driver` HAL plug-in (macOS): copies it
/// from the app bundle's Resources to `/Library/Audio/Plug-Ins/HAL` and
/// restarts `coreaudiod`, through the standard administrator prompt
/// (`osascript ... with administrator privileges`). That's why the app runs
/// without the App Sandbox.
@LazySingleton(as: VirtualMicInstallerDataSource)
class MacosHalInstallerDataSource implements VirtualMicInstallerDataSource {
  MacosHalInstallerDataSource({
    @ignoreParam RunProcess? runProcess,
    @ignoreParam String? bundledDriverPath,
    @ignoreParam bool Function(String path)? driverExists,
  }) : _run = runProcess ?? Process.run,
       _driverPath = bundledDriverPath ?? _defaultDriverPath(),
       _exists = driverExists ?? ((p) => Directory(p).existsSync());

  static const halDirectory = '/Library/Audio/Plug-Ins/HAL';
  static const driverName = 'MuteAround.driver';

  /// `osascript` error number for "User canceled."
  static const _userCanceled = '-128';

  final RunProcess _run;
  final String _driverPath;
  final bool Function(String) _exists;

  @override
  Future<Result<Unit>> install() async {
    if (!_exists(_driverPath)) {
      return Err(
        InstallFailure('The plug-in is missing from the app at $_driverPath'),
      );
    }
    try {
      final result = await _run('/usr/bin/osascript', [
        '-e',
        installScript(_driverPath),
      ]);
      if (result.exitCode == 0) return const Ok(unit);
      final stderr = '${result.stderr}'.trim();
      if (stderr.contains(_userCanceled)) {
        return const Err(UserCancelled('Administrator prompt cancelled'));
      }
      return Err(InstallFailure(stderr));
    } on ProcessException catch (e) {
      return Err(InstallFailure('$e'));
    }
  }

  /// The AppleScript that installs [driverPath] as root.
  static String installScript(String driverPath) {
    final dest = '$halDirectory/$driverName';
    final shell = [
      '/bin/mkdir -p ${_sh(halDirectory)}',
      '/bin/rm -rf ${_sh(dest)}',
      '/bin/cp -R ${_sh(driverPath)} ${_sh(dest)}',
      '/usr/sbin/chown -R root:wheel ${_sh(dest)}',
      '/usr/bin/killall -9 coreaudiod',
    ].join(' && ');
    return 'do shell script "${_appleScriptString(shell)}" '
        'with administrator privileges';
  }

  /// Single-quotes [s] for /bin/sh.
  static String _sh(String s) => "'${s.replaceAll("'", r"'\''")}'";

  /// Escapes [s] for an AppleScript string literal.
  static String _appleScriptString(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  /// `<App>.app/Contents/Resources/MuteAround.driver`, copied there by the
  /// Xcode build phase (`macos/scripts/build_hal.sh`).
  static String _defaultDriverPath() {
    final macosDir = File(Platform.resolvedExecutable).parent;
    return '${macosDir.parent.path}/Resources/$driverName';
  }
}
