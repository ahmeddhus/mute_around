import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/level_meter.dart';

void main() {
  var now = Duration.zero;

  Future<void> pump(WidgetTester tester, double peakDb) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LevelMeter(
          label: 'Input',
          peakDb: peakDb,
          rmsDb: peakDb - 6,
          clock: () => now,
        ),
      ),
    ),
  );

  setUp(() => now = Duration.zero);

  testWidgets('exposes the level to screen readers', (tester) async {
    await pump(tester, -23.4);
    expect(
      tester.getSemantics(find.byType(LevelMeter)),
      matchesSemantics(label: 'Input', value: '-23 dB'),
    );
  });

  testWidgets('silence reads as "silent"', (tester) async {
    await pump(tester, -90);
    expect(find.text('silent'), findsOneWidget);
  });

  testWidgets('peak falls back over ~300 ms instead of dropping', (
    tester,
  ) async {
    await pump(tester, -10);
    now = const Duration(milliseconds: 100);
    await pump(tester, -60);
    // 100 ms at a 300 ms time constant ≈ 2.9 dB.
    expect(find.text('-13 dB'), findsOneWidget);
    now = const Duration(seconds: 3);
    await pump(tester, -60);
    expect(find.text('-60 dB'), findsOneWidget);
  });

  testWidgets('a louder reading shows immediately', (tester) async {
    await pump(tester, -40);
    now = const Duration(milliseconds: 33);
    await pump(tester, -5);
    expect(find.text('-5 dB'), findsOneWidget);
  });
}
