import 'package:mute_around/app/tray/desktop_window.dart';
import 'package:mute_around/app/tray/tray_host.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_ui_visible.dart';

/// The desktop integration the app runs inside: the tray icon, the
/// main window, and how to tell the engine whether the UI is visible.
/// `main.dart` provides the real one; widget tests run without it.
final class DesktopShell {
  const DesktopShell({
    required this.tray,
    required this.window,
    required this.setUiVisible,
  });

  final TrayHost tray;
  final DesktopWindow window;
  final SetUiVisible setUiVisible;
}
