import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/app/app.dart';
import 'package:mute_around/core/app_version.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';
import 'package:mute_around/features/pipeline/domain/entities/engine_stats.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/usecases/stop_pipeline.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/diagnostics_cubit.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/levels_cubit.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/settings/domain/usecases/flush_settings.dart';
import 'package:mute_around/features/setup/domain/entities/readiness.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';
import 'package:mute_around/features/setup/presentation/bloc/setup_cubit.dart';

class MockPipelineBloc extends MockBloc<PipelineEvent, PipelineState>
    implements PipelineBloc {}

class MockSetupCubit extends MockCubit<SetupState> implements SetupCubit {}

class MockLevelsCubit extends MockCubit<AudioLevels> implements LevelsCubit {}

class MockDiagnosticsCubit extends MockCubit<EngineStats?>
    implements DiagnosticsCubit {}

class MockStopPipeline extends Mock implements StopPipeline {}

class MockFlushSettings extends Mock implements FlushSettings {}

const _ready = SetupState(
  readiness: Readiness(
    platform: .macos,
    virtualMic: VirtualMicStatus.ready('sink'),
    permission: .granted,
  ),
);
const _missing = SetupState(
  readiness: Readiness(
    platform: .macos,
    virtualMic: VirtualMicStatus.notInstalled(.macos),
    permission: .granted,
  ),
);

void main() {
  late MockPipelineBloc bloc;
  late MockSetupCubit setup;
  late MockStopPipeline stop;
  late MockFlushSettings flush;
  late StreamController<SetupState> setupStates;
  late StreamController<PipelineState> pipelineStates;

  setUpAll(() => registerFallbackValue(const PipelineEvent.retryRequested()));

  setUp(() {
    bloc = MockPipelineBloc();
    setup = MockSetupCubit();
    stop = MockStopPipeline();
    flush = MockFlushSettings();
    setupStates = StreamController.broadcast();
    pipelineStates = StreamController.broadcast();
    when(() => flush()).thenAnswer((_) async {});
    when(() => stop()).thenAnswer((_) async => const Ok(unit));
    when(() => bloc.state).thenReturn(const PipelineState());
    when(() => setup.state).thenReturn(const SetupState());
    whenListen(bloc, pipelineStates.stream);
    whenListen(setup, setupStates.stream);
    when(
      () => setup.recheck(userInitiated: any(named: 'userInitiated')),
    ).thenAnswer((_) async {});
    when(() => setup.appResumed()).thenAnswer((_) async {});
    when(() => setup.engineReportedPermissionDenied()).thenAnswer((_) async {});
  });

  tearDown(() async {
    await setupStates.close();
    await pipelineStates.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MuteAround(
        createPipelineBloc: () => bloc,
        createSetupCubit: () => setup,
        createDiagnosticsCubit: () {
          final d = MockDiagnosticsCubit();
          when(() => d.state).thenReturn(null);
          return d;
        },
        appVersion: const AppVersion('1.0.0+1'),
        createLevelsCubit: () {
          final levels = MockLevelsCubit();
          when(() => levels.state).thenReturn(AudioLevels.silent);
          return levels;
        },
        stopPipeline: stop,
        flushSettings: flush,
        hostInfo: const HostInfo(.macos),
      ),
    );
    await tester.pump();
  }

  Future<void> emitSetup(WidgetTester tester, SetupState state) async {
    when(() => setup.state).thenReturn(state);
    setupStates.add(state);
    await tester.pumpAndSettle();
  }

  testWidgets('checks readiness at launch; nothing starts before', (
    tester,
  ) async {
    await pumpApp(tester);
    verify(() => setup.recheck()).called(1);
    verifyNever(() => bloc.add(any()));
    expect(find.text('Mute Around'), findsOneWidget);
  });

  testWidgets('ready → readinessChanged(true), stays Home', (tester) async {
    await pumpApp(tester);
    await emitSetup(tester, _ready);
    verify(
      () => bloc.add(const PipelineEvent.readinessChanged(ready: true)),
    ).called(1);
    expect(find.text('Starting…'), findsOneWidget);
  });

  testWidgets('missing virtual mic → Setup screen, then Home when ready', (
    tester,
  ) async {
    await pumpApp(tester);
    await emitSetup(tester, _missing);
    expect(find.text('Set up Mute Around'), findsOneWidget);
    verify(
      () => bloc.add(const PipelineEvent.readinessChanged(ready: false)),
    ).called(1);
    await emitSetup(tester, _ready);
    expect(find.text('Set up Mute Around'), findsNothing);
    verify(
      () => bloc.add(const PipelineEvent.readinessChanged(ready: true)),
    ).called(1);
  });

  testWidgets('virtual mic removed while Home is open → back to Setup', (
    tester,
  ) async {
    await pumpApp(tester);
    await emitSetup(tester, _ready);
    await emitSetup(tester, _missing);
    expect(find.text('Set up Mute Around'), findsOneWidget);
  });

  testWidgets('pipeline SetupRequired / PermissionNeeded → setup re-checks', (
    tester,
  ) async {
    await pumpApp(tester);
    clearInteractions(setup);
    pipelineStates.add(
      const PipelineState(status: PipelineStatus.setupRequired()),
    );
    await tester.pump();
    verify(() => setup.recheck()).called(1);
    pipelineStates.add(
      const PipelineState(status: PipelineStatus.permissionNeeded()),
    );
    await tester.pump();
    verify(() => setup.engineReportedPermissionDenied()).called(1);
  });

  testWidgets('resuming the app re-checks setup', (tester) async {
    await pumpApp(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    verify(() => setup.appResumed()).called(1);
  });

  testWidgets('quitting stops the pipeline, flushes settings, then exits', (
    tester,
  ) async {
    await pumpApp(tester);
    final response = await tester.binding.handleRequestAppExit();
    expect(response, AppExitResponse.exit);
    verifyInOrder([() => stop(), () => flush()]);
  });
}
