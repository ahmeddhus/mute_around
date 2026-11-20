import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/usecases/start_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/stop_pipeline.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';

class MockStartPipeline extends Mock implements StartPipeline {}

class MockStopPipeline extends Mock implements StopPipeline {}

class MockWatchPipelineStatus extends Mock implements WatchPipelineStatus {}

void main() {
  late MockStartPipeline start;
  late MockStopPipeline stop;
  late MockWatchPipelineStatus watch;
  late StreamController<PipelineStatus> engineStatus;

  setUp(() {
    start = MockStartPipeline();
    stop = MockStopPipeline();
    watch = MockWatchPipelineStatus();
    engineStatus = StreamController<PipelineStatus>.broadcast();
    when(() => watch()).thenAnswer((_) => engineStatus.stream);
    when(() => stop()).thenAnswer((_) async => const Ok(unit));
  });
  tearDown(() => engineStatus.close());

  PipelineBloc build() => PipelineBloc(start, stop, watch);
  PipelineState s(PipelineStatus status) => PipelineState(status: status);

  test(
    'starts in Starting and does not start the engine on creation',
    () async {
      final bloc = build();
      expect(bloc.state, s(const PipelineStatus.starting()));
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => start());
      await bloc.close();
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'readinessChanged(ready) → Starting → Processing',
    setUp: () => when(() => start()).thenAnswer((_) async => const Ok(unit)),
    build: build,
    act: (bloc) => bloc.add(const PipelineEvent.readinessChanged(ready: true)),
    expect: () => [
      s(const PipelineStatus.starting()),
      s(const PipelineStatus.processing()),
    ],
    verify: (_) => verify(() => start()).called(1),
  );

  blocTest<PipelineBloc, PipelineState>(
    'follows engine status changes after starting',
    setUp: () => when(() => start()).thenAnswer((_) async => const Ok(unit)),
    build: build,
    act: (bloc) async {
      bloc.add(const PipelineEvent.readinessChanged(ready: true));
      await Future<void>.delayed(Duration.zero);
      engineStatus.add(const PipelineStatus.bypassed(.user));
      engineStatus.add(const PipelineStatus.deviceDisconnected('usb'));
    },
    expect: () => [
      s(const PipelineStatus.starting()),
      s(const PipelineStatus.processing()),
      s(const PipelineStatus.bypassed(.user)),
      s(const PipelineStatus.deviceDisconnected('usb')),
    ],
  );

  blocTest<PipelineBloc, PipelineState>(
    'ready twice starts once',
    setUp: () => when(() => start()).thenAnswer((_) async => const Ok(unit)),
    build: build,
    act: (bloc) => bloc
      ..add(const PipelineEvent.readinessChanged(ready: true))
      ..add(const PipelineEvent.readinessChanged(ready: true)),
    verify: (_) => verify(() => start()).called(1),
  );

  final failures = <Failure, PipelineStatus>{
    const DeviceNotFound(): const PipelineStatus.noInputDevice(),
    const VirtualMicMissing(): const PipelineStatus.setupRequired(
      VirtualMicMissing(),
    ),
    const PermissionDenied(): const PipelineStatus.permissionNeeded(),
    const ModelLoadFailure('m'): const PipelineStatus.engineError(
      ModelLoadFailure('m'),
    ),
    const DeviceFailure('d'): const PipelineStatus.engineError(
      DeviceFailure('d'),
    ),
  };
  for (final MapEntry(key: failure, value: status) in failures.entries) {
    blocTest<PipelineBloc, PipelineState>(
      'start failing with ${failure.runtimeType} → ${status.runtimeType}',
      setUp: () => when(() => start()).thenAnswer((_) async => Err(failure)),
      build: build,
      act: (bloc) =>
          bloc.add(const PipelineEvent.readinessChanged(ready: true)),
      expect: () => [s(const PipelineStatus.starting()), s(status)],
    );
  }

  blocTest<PipelineBloc, PipelineState>(
    'retry after an error starts again',
    setUp: () {
      var attempts = 0;
      when(() => start()).thenAnswer(
        (_) async =>
            attempts++ == 0 ? const Err(DeviceFailure('busy')) : const Ok(unit),
      );
    },
    build: build,
    act: (bloc) async {
      bloc.add(const PipelineEvent.readinessChanged(ready: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const PipelineEvent.retryRequested());
    },
    expect: () => [
      s(const PipelineStatus.starting()),
      s(const PipelineStatus.engineError(DeviceFailure('busy'))),
      s(const PipelineStatus.starting()),
      s(const PipelineStatus.processing()),
    ],
  );

  blocTest<PipelineBloc, PipelineState>(
    'readiness lost stops the engine → SetupRequired',
    setUp: () => when(() => start()).thenAnswer((_) async => const Ok(unit)),
    build: build,
    act: (bloc) async {
      bloc.add(const PipelineEvent.readinessChanged(ready: true));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const PipelineEvent.readinessChanged(ready: false));
    },
    expect: () => [
      s(const PipelineStatus.starting()),
      s(const PipelineStatus.processing()),
      s(const PipelineStatus.setupRequired()),
    ],
    verify: (_) => verify(() => stop()).called(1),
  );
}
