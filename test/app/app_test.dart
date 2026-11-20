import 'dart:ui' show AppExitResponse;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/app/app.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/usecases/stop_pipeline.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';

class MockPipelineBloc extends MockBloc<PipelineEvent, PipelineState>
    implements PipelineBloc {}

class MockStopPipeline extends Mock implements StopPipeline {}

void main() {
  late MockPipelineBloc bloc;
  late MockStopPipeline stop;

  setUp(() {
    bloc = MockPipelineBloc();
    stop = MockStopPipeline();
    when(() => bloc.state).thenReturn(
      const PipelineState(status: PipelineStatus.processing()),
    );
    when(() => stop()).thenAnswer((_) async => const Ok(unit));
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MuteAround(
        createPipelineBloc: () => bloc,
        stopPipeline: stop,
        hostInfo: const HostInfo(.macos),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows Home and sends readiness once at launch', (tester) async {
    await pumpApp(tester);
    expect(find.text('Mute Around'), findsOneWidget);
    expect(find.text('Processing'), findsOneWidget);
    verify(
      () => bloc.add(const PipelineEvent.readinessChanged(ready: true)),
    ).called(1);
  });

  testWidgets('quitting stops the pipeline, then exits', (tester) async {
    await pumpApp(tester);
    final response = await tester.binding.handleRequestAppExit();
    expect(response, AppExitResponse.exit);
    verify(() => stop()).called(1);
  });
}
