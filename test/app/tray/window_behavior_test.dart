import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/app/tray/desktop_window.dart';
import 'package:mute_around/app/tray/window_behavior.dart';
import 'package:mute_around/features/pipeline/domain/usecases/set_ui_visible.dart';

class FakeWindow implements DesktopWindow {
  void Function()? onClose;
  final calls = <String>[];

  @override
  void interceptClose(void Function() onCloseRequested) =>
      onClose = onCloseRequested;

  @override
  void show() => calls.add('show');

  @override
  void hide() => calls.add('hide');
}

class MockSetUiVisible extends Mock implements SetUiVisible {}

void main() {
  late FakeWindow window;
  late MockSetUiVisible visible;

  setUp(() {
    window = FakeWindow();
    visible = MockSetUiVisible();
    when(() => visible(visible: any(named: 'visible'))).thenReturn(null);
  });

  test('closing the window hides it; the engine polls slower', () {
    WindowBehavior(window, visible).init();
    window.onClose!();
    expect(window.calls, ['hide']);
    verify(() => visible(visible: false)).called(1);
  });

  test('Open shows the window again; the meters resume', () {
    WindowBehavior(window, visible).showWindow();
    expect(window.calls, ['show']);
    verify(() => visible(visible: true)).called(1);
  });
}
