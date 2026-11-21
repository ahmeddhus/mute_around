import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/app_version.dart';
import 'package:mute_around/features/pipeline/domain/entities/engine_stats.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/diagnostics_cubit.dart';
import 'package:mute_around/features/pipeline/presentation/pages/about_page.dart';

class MockDiagnosticsCubit extends MockCubit<EngineStats?>
    implements DiagnosticsCubit {}

void main() {
  late MockDiagnosticsCubit cubit;

  setUp(() => cubit = MockDiagnosticsCubit());

  Future<void> pump(WidgetTester tester, EngineStats? stats) async {
    when(() => cubit.state).thenReturn(stats);
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: const AppVersion('1.2.3+4'),
        child: BlocProvider<DiagnosticsCubit>.value(
          value: cubit,
          child: const MaterialApp(home: AboutPage()),
        ),
      ),
    );
  }

  testWidgets('shows the version', (tester) async {
    await pump(tester, null);
    expect(find.text('Version 1.2.3+4'), findsOneWidget);
  });

  testWidgets('the licenses button opens the licenses page', (tester) async {
    await pump(tester, null);
    await tester.tap(find.text('Open-source licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('diagnostics show the engine stats', (tester) async {
    await pump(
      tester,
      const EngineStats(
        framesProcessed: 1234,
        avgProcessMs: 0.42,
        estimatedLatencyMs: 30.5,
        underruns: 2,
        overloadEvents: 1,
      ),
    );
    expect(find.text('30.5 ms'), findsOneWidget);
    expect(find.text('0.42 ms'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('no stats yet', (tester) async {
    await pump(tester, null);
    expect(find.text('The audio engine has not started.'), findsOneWidget);
  });
}
