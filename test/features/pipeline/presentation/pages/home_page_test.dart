import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/pipeline/presentation/pages/home_page.dart';

class MockPipelineBloc extends MockBloc<PipelineEvent, PipelineState>
    implements PipelineBloc {}

void main() {
  late MockPipelineBloc bloc;

  setUp(() => bloc = MockPipelineBloc());

  Future<void> pump(
    WidgetTester tester,
    PipelineStatus status, {
    HostPlatform platform = .macos,
  }) async {
    when(() => bloc.state).thenReturn(PipelineState(status: status));
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: HostInfo(platform),
        child: BlocProvider<PipelineBloc>.value(
          value: bloc,
          child: const MaterialApp(home: HomePage()),
        ),
      ),
    );
  }

  final banners = <PipelineStatus, String>{
    const PipelineStatus.starting(): 'Starting…',
    const PipelineStatus.processing(): 'Processing',
    const PipelineStatus.bypassed(.user): 'Bypassed',
    const PipelineStatus.bypassed(.overload): 'Bypassed — computer too busy',
    const PipelineStatus.deviceDisconnected('usb'): 'Microphone disconnected',
    const PipelineStatus.noInputDevice(): 'No microphone',
    const PipelineStatus.setupRequired(): 'Setup needed',
    const PipelineStatus.permissionNeeded(): 'Microphone access needed',
    const PipelineStatus.engineError(UnknownFailure()): 'Something went wrong',
  };
  for (final MapEntry(key: status, value: text) in banners.entries) {
    testWidgets('banner shows "$text" for $status', (tester) async {
      await pump(tester, status);
      expect(find.text(text), findsOneWidget);
    });
  }

  testWidgets('macOS hint names Mute Around', (tester) async {
    await pump(tester, const PipelineStatus.processing());
    expect(
      find.textContaining(
        'choose Mute Around as the microphone',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Windows hint names CABLE Output', (tester) async {
    await pump(tester, const PipelineStatus.processing(), platform: .windows);
    expect(
      find.textContaining(
        'choose CABLE Output as the microphone',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('no Try again while processing', (tester) async {
    await pump(tester, const PipelineStatus.processing());
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('Try again on an engine error retries', (tester) async {
    await pump(tester, const PipelineStatus.engineError(DeviceFailure()));
    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const PipelineEvent.retryRequested())).called(1);
  });
}
