import 'package:mute_around/app/tray/desktop_window.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_ui_visible.dart';

/// Hide-to-tray: closing the window hides it and processing goes on;
/// the tray's "Open Mute Around" brings it back. While hidden, the engine
/// status is polled at 4 Hz instead of 30 Hz and the meters pause.
///
/// Quitting is not handled here: it goes through the app's single exit path
/// (`AppLifecycleListener.onExitRequested` in `app.dart`).
class WindowBehavior {
  WindowBehavior(this._window, this._setUiVisible);

  final DesktopWindow _window;
  final SetUiVisible _setUiVisible;

  void init() => _window.interceptClose(hideToTray);

  void hideToTray() {
    _window.hide();
    _setUiVisible(visible: false);
  }

  void showWindow() {
    _window.show();
    _setUiVisible(visible: true);
  }
}
