import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/processing_controls.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

void main() {
  final bypass = <bool>[];
  final agc = <bool>[];
  final strength = <SuppressionStrength>[];

  setUp(() {
    bypass.clear();
    agc.clear();
    strength.clear();
  });

  Future<void> pump(
    WidgetTester tester, {
    bool userBypass = false,
    bool agcEnabled = true,
    SuppressionStrength current = .medium,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProcessingControls(
          userBypass: userBypass,
          strength: current,
          agcEnabled: agcEnabled,
          onBypassChanged: bypass.add,
          onStrengthChanged: strength.add,
          onAgcChanged: agc.add,
        ),
      ),
    ),
  );

  testWidgets('bypass toggle', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Bypass (hear raw mic)'));
    expect(bypass, [true]);
  });

  testWidgets('Low / Medium / High, Medium selected by default', (
    tester,
  ) async {
    await pump(tester);
    final button = tester.widget<SegmentedButton<SuppressionStrength>>(
      find.byType(SegmentedButton<SuppressionStrength>),
    );
    expect(button.selected, {SuppressionStrength.medium});
    await tester.tap(find.text('Low'));
    await tester.tap(find.text('High'));
    expect(strength, [SuppressionStrength.low, SuppressionStrength.high]);
  });

  testWidgets('auto gain switch reflects and changes the value', (
    tester,
  ) async {
    await pump(tester, agcEnabled: false);
    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Auto gain'),
    );
    expect(tile.value, isFalse);
    await tester.tap(find.text('Auto gain'));
    expect(agc, [true]);
  });
}
