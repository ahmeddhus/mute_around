import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

import 'pipeline_bloc_harness.dart';

void main() {
  late PipelineHarness h;

  setUp(() => h = PipelineHarness());
  tearDown(() => h.dispose());

  test(
    'starts in Starting and does not start the engine on creation',
    () async {
      final bloc = h.build();
      expect(bloc.state.status, const PipelineStatus.starting());
      await settle();
      verifyNever(() => h.start());
      await bloc.close();
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'readinessChanged(ready) → Starting → Processing, with the device used',
    build: () => h.build(),
    act: (bloc) => bloc.add(const PipelineEvent.readinessChanged(ready: true)),
    expect: () => [
      hasStatus(const PipelineStatus.starting()),
      const PipelineState(
        status: PipelineStatus.processing(),
        selectedDeviceId: 'builtin',
      ),
    ],
    verify: (_) => verify(() => h.start()).called(1),
  );

  blocTest<PipelineBloc, PipelineState>(
    'shows the saved settings; a saved bypass starts as Bypassed(user)',
    setUp: () => h.settings = const ProcessingSettings(
      userBypass: true,
      agcEnabled: false,
      strength: .high,
    ),
    build: () => h.build(),
    act: startReady,
    expect: () => [
      hasStatus(const PipelineStatus.starting()),
      const PipelineState(
        userBypass: true,
        agcEnabled: false,
        strength: .high,
      ),
      const PipelineState(
        status: PipelineStatus.bypassed(.user),
        selectedDeviceId: 'builtin',
        userBypass: true,
        agcEnabled: false,
        strength: .high,
      ),
    ],
  );

  blocTest<PipelineBloc, PipelineState>(
    'follows engine status changes after starting',
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      h.engineStatus.add(const PipelineStatus.bypassed(.overload));
      h.engineStatus.add(const PipelineStatus.deviceDisconnected('builtin'));
    },
    skip: 2,
    expect: () => [
      hasStatus(const PipelineStatus.bypassed(.overload)),
      hasStatus(const PipelineStatus.deviceDisconnected('builtin')),
    ],
  );

  blocTest<PipelineBloc, PipelineState>(
    'ready twice starts once',
    build: () => h.build(),
    act: (bloc) => bloc
      ..add(const PipelineEvent.readinessChanged(ready: true))
      ..add(const PipelineEvent.readinessChanged(ready: true)),
    verify: (_) => verify(() => h.start()).called(1),
  );

  blocTest<PipelineBloc, PipelineState>(
    'no start before readiness; retry is ignored too',
    build: () => h.build(),
    act: (bloc) => bloc.add(const PipelineEvent.retryRequested()),
    expect: () => <PipelineState>[],
    verify: (_) => verifyNever(() => h.start()),
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
      setUp: () => when(() => h.start()).thenAnswer((_) async => Err(failure)),
      build: () => h.build(),
      act: (bloc) =>
          bloc.add(const PipelineEvent.readinessChanged(ready: true)),
      expect: () => [
        hasStatus(const PipelineStatus.starting()),
        hasStatus(status),
      ],
    );
  }

  blocTest<PipelineBloc, PipelineState>(
    'retry after an error starts again',
    setUp: () {
      var attempts = 0;
      when(() => h.start()).thenAnswer(
        (_) async => attempts++ == 0
            ? const Err(DeviceFailure('busy'))
            : const Ok('builtin'),
      );
    },
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      bloc.add(const PipelineEvent.retryRequested());
    },
    expect: () => [
      hasStatus(const PipelineStatus.starting()),
      hasStatus(const PipelineStatus.engineError(DeviceFailure('busy'))),
      hasStatus(const PipelineStatus.starting()),
      hasStatus(const PipelineStatus.processing()),
    ],
  );

  blocTest<PipelineBloc, PipelineState>(
    'readiness lost stops the engine → SetupRequired; engine updates ignored',
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      bloc.add(const PipelineEvent.readinessChanged(ready: false));
      await settle();
      h.engineStatus.add(const PipelineStatus.processing());
    },
    skip: 2,
    expect: () => [hasStatus(const PipelineStatus.setupRequired())],
    verify: (_) => verify(() => h.stop()).called(1),
  );
}
