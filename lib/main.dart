import 'package:material_ui/material_ui.dart';
import 'package:mute_around/app/app.dart';
import 'package:mute_around/app/di.dart';
import 'package:mute_around/app/licenses.dart';
import 'package:mute_around/app/tray/desktop_shell.dart';
import 'package:mute_around/app/tray/desktop_window.dart';
import 'package:mute_around/app/tray/tray_host.dart';
import 'package:mute_around/core/app_version.dart';
import 'package:nativeapi/nativeapi.dart' show AppInfo;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  registerNativeLicenses();
  final info = AppInfo.instance;
  final version = [info.getVersion(), info.getBuildNumber()].nonNulls;
  runApp(
    MuteAround(
      createPipelineBloc: getIt.call,
      createSetupCubit: getIt.call,
      createLevelsCubit: getIt.call,
      createDiagnosticsCubit: getIt.call,
      appVersion: AppVersion(version.isEmpty ? 'unknown' : version.join('+')),
      stopPipeline: getIt(),
      flushSettings: getIt(),
      hostInfo: getIt(),
      shell: DesktopShell(
        tray: NativeTrayHost(),
        window: NativeDesktopWindow(),
        setUiVisible: getIt(),
      ),
    ),
  );
}
