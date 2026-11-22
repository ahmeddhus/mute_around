import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/engine_stats.dart';
import 'package:mute_around/features/pipeline/domain/usecases/get_engine_stats.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/diagnostics_cubit.dart';

class MockGetEngineStats extends Mock implements GetEngineStats {}

EngineStats stats(int frames) => EngineStats(
  framesProcessed: frames,
  avgProcessMs: 0.4,
  estimatedLatencyMs: 30,
  underruns: 0,
  overloadEvents: 0,
);

void main() {
  late MockGetEngineStats get;

  setUp(() => get = MockGetEngineStats());

  blocTest<DiagnosticsCubit, EngineStats?>(
    'reads the stats at once and then every interval',
    setUp: () {
      var frames = 0;
      when(get.call).thenAnswer((_) => Ok(stats(frames += 100)));
    },
    build: () =>
        DiagnosticsCubit(get, interval: const Duration(milliseconds: 10)),
    wait: const Duration(milliseconds: 35),
    verify: (cubit) {
      expect(cubit.state!.framesProcessed, greaterThanOrEqualTo(300));
    },
  );

  blocTest<DiagnosticsCubit, EngineStats?>(
    'stays empty while the engine reports an error',
    setUp: () => when(
      get.call,
    ).thenReturn(const Err(EngineStateFailure('not created'))),
    build: () =>
        DiagnosticsCubit(get, interval: const Duration(milliseconds: 10)),
    wait: const Duration(milliseconds: 25),
    expect: () => <EngineStats?>[],
  );
}
