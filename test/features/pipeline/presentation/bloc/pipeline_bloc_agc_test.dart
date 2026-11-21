import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';

import 'pipeline_bloc_harness.dart';

void main() {
  late PipelineHarness h;

  setUp(() => h = PipelineHarness());
  tearDown(() => h.dispose());

  blocTest<PipelineBloc, PipelineState>(
    'auto gain off: shown at once, sent to the engine (which persists it)',
    build: () => h.build(),
    act: (bloc) => bloc.add(const PipelineEvent.agcToggled(enabled: false)),
    expect: () => [const PipelineState(agcEnabled: false)],
    verify: (_) => verify(() => h.setAgc(enabled: false)).called(1),
  );

  blocTest<PipelineBloc, PipelineState>(
    'auto gain toggle failing: reverted and the failure shown',
    setUp: () => when(
      () => h.setAgc(enabled: false),
    ).thenAnswer((_) async => const Err(UnknownFailure('disk'))),
    build: () => h.build(),
    act: (bloc) => bloc.add(const PipelineEvent.agcToggled(enabled: false)),
    expect: () => [
      const PipelineState(agcEnabled: false),
      const PipelineState(controlFailure: UnknownFailure('disk')),
    ],
  );
}
