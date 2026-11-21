import 'package:window_manager/window_manager.dart';

/// The app's main window, as far as hide-to-tray needs it. An interface so
/// `WindowBehavior` can be tested without a real window.
abstract interface class DesktopWindow {
  /// Runs [onCloseRequested] instead of closing when the user closes the
  /// window (red button, Alt+F4, Ctrl+W).
  void interceptClose(void Function() onCloseRequested);

  void show();

  void hide();
}

/// [DesktopWindow] on `window_manager`'s native API.
final class NativeDesktopWindow implements DesktopWindow {
  Window? get _window => WindowManager.instance.getCurrent();

  @override
  void interceptClose(void Function() onCloseRequested) {
    _window?.addListener((event) {
      if (event is WindowCloseRequestedEvent) {
        event.request.cancel();
        onCloseRequested();
      }
    });
  }

  @override
  void show() {
    final window = _window;
    if (window == null) return;
    window
      ..show()
      ..focus();
  }

  @override
  void hide() => _window?.hide();
}
