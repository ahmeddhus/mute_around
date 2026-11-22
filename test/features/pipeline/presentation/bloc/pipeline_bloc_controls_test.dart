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

  blocTest<PipelineBloc, PipelineState>(
    'bypass on while processing → Bypassed(user) at once',
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      bloc.add(const PipelineEvent.bypassToggled(enabled: true));
    },
    skip: 2,
    expect: () => [
      isA<PipelineState>()
          .having((s) => s.userBypass, 'userBypass', true)
          .having((s) => s.status, 'status', const PipelineStatus.processing()),
      hasStatus(const PipelineStatus.bypassed(.user)),
    ],
    verify: (_) => verify(() => h.setBypass(enabled: true)).called(1),
  );

  blocTest<PipelineBloc, PipelineState>(
    'bypass off → Processing',
    setUp: () => h.settings = const ProcessingSettings(userBypass: true),
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      bloc.add(const PipelineEvent.bypassToggled(enabled: false));
      await settle();
    },
    verify: (bloc) {
      expect(bloc.state.userBypass, isFalse);
      expect(bloc.state.status, const PipelineStatus.processing());
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'bypass while not running only changes the setting',
    build: () => h.build(),
    act: (bloc) => bloc.add(const PipelineEvent.bypassToggled(enabled: true)),
    expect: () => [const PipelineState(userBypass: true)],
  );

  blocTest<PipelineBloc, PipelineState>(
    'bypass toggle failing: reverted, status restored, failure shown',
    setUp: () => when(
      () => h.setBypass(enabled: true),
    ).thenAnswer((_) async => const Err(EngineStateFailure('x'))),
    build: () => h.build(),
    act: (bloc) async {
      await startReady(bloc);
      bloc.add(const PipelineEvent.bypassToggled(enabled: true));
      await settle();
    },
    verify: (bloc) {
      expect(bloc.state.userBypass, isFalse);
      expect(bloc.state.status, const PipelineStatus.processing());
      expect(bloc.state.controlFailure, const EngineStateFailure('x'));
    },
  );

  blocTest<PipelineBloc, PipelineState>(
    'strength change is shown at once and sent to the engine',
    build: () => h.build(),
    act: (bloc) => bloc.add(const PipelineEvent.strengthChanged(.high)),
    expect: () => [const PipelineState(strength: .high)],
    verify: (_) => verify(() => h.setStrength(.high)).called(1),
  );

  blocTest<PipelineBloc, PipelineState>(
    'strength change failing is reverted',
    setUp: () => when(
      () => h.setStrength(.low),
    ).thenAnswer((_) async => const Err(EngineStateFailure())),
    build: () => h.build(),
    act: (bloc) => bloc.add(const PipelineEvent.strengthChanged(.low)),
    expect: () => [
      const PipelineState(strength: .low),
      const PipelineState(controlFailure: EngineStateFailure()),
    ],
  );

  group('Bypassed(user) vs Bypassed(overload)', () {
    blocTest<PipelineBloc, PipelineState>(
      'the engine reports overload → "computer too busy"',
      build: () => h.build(),
      act: (bloc) async {
        await startReady(bloc);
        h.engineStatus.add(const PipelineStatus.bypassed(.overload));
        await settle();
        h.engineStatus.add(const PipelineStatus.processing());
      },
      skip: 2,
      expect: () => [
        hasStatus(const PipelineStatus.bypassed(.overload)),
        hasStatus(const PipelineStatus.processing()),
      ],
    );

    blocTest<PipelineBloc, PipelineState>(
      'user bypass on during overload → Bypassed(user) (user wins)',
      build: () => h.build(),
      act: (bloc) async {
        await startReady(bloc);
        h.engineStatus.add(const PipelineStatus.bypassed(.overload));
        await settle();
        bloc.add(const PipelineEvent.bypassToggled(enabled: true));
        await settle();
      },
      verify: (bloc) =>
          expect(bloc.state.status, const PipelineStatus.bypassed(.user)),
    );

    blocTest<PipelineBloc, PipelineState>(
      'user bypass off during overload keeps "computer too busy"',
      setUp: () => h.settings = const ProcessingSettings(userBypass: true),
      build: () => h.build(),
      act: (bloc) async {
        await startReady(bloc);
        h.engineStatus.add(const PipelineStatus.bypassed(.overload));
        await settle();
        bloc.add(const PipelineEvent.bypassToggled(enabled: false));
        await settle();
      },
      verify: (bloc) =>
          expect(bloc.state.status, const PipelineStatus.bypassed(.overload)),
    );
  });
}
