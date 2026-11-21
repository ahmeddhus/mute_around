import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/domain/entities/input_device.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/input_device_dropdown.dart';

void main() {
  final builtIn = InputDevice(id: 'builtin', name: 'MacBook Mic');
  final usb = InputDevice(id: 'usb', name: 'USB Mic');

  Future<List<String>> pump(
    WidgetTester tester,
    List<InputDevice> devices,
    String? selected,
  ) async {
    final picked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InputDeviceDropdown(
            devices: devices,
            selectedId: selected,
            onSelected: picked.add,
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('lists devices by name and reports a new pick', (tester) async {
    final picked = await pump(tester, [builtIn, usb], 'builtin');
    expect(find.text('MacBook Mic'), findsOneWidget);
    await tester.tap(find.text('MacBook Mic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USB Mic').last);
    await tester.pumpAndSettle();
    expect(picked, ['usb']);
  });

  testWidgets('picking the current device again does nothing', (tester) async {
    final picked = await pump(tester, [builtIn, usb], 'builtin');
    await tester.tap(find.text('MacBook Mic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MacBook Mic').last);
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
  });

  testWidgets('no microphone: disabled with an explanation', (tester) async {
    final picked = await pump(tester, [], null);
    expect(find.text('No microphone'), findsOneWidget);
    expect(find.textContaining('connect one to start'), findsOneWidget);
    await tester.tap(find.text('No microphone'));
    await tester.pumpAndSettle();
    expect(picked, isEmpty);
  });

  testWidgets('selected device unplugged: shown as disconnected', (
    tester,
  ) async {
    await pump(tester, [
      builtIn,
      usb.copyWith(isConnected: false),
    ], 'usb');
    expect(find.text('USB Mic (disconnected)'), findsOneWidget);
    expect(find.textContaining('Microphone disconnected'), findsOneWidget);
  });
}
