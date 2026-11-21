import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/result.dart';
import 'package:mute_around/features/pipeline/domain/entities/engine_stats.dart';
import 'package:mute_around/features/pipeline/domain/repositories/audio_engine_repository.dart';
import 'package:mute_around/features/pipeline/domain/usecases/get_engine_stats.dart';

class MockAudioEngineRepository extends Mock implements AudioEngineRepository {}

void main() {
  late MockAudioEngineRepository engine;

  setUp(() => engine = MockAudioEngineRepository());

  test('returns the repository stats', () {
    const stats = EngineStats(
      framesProcessed: 1,
      avgProcessMs: 0.5,
      estimatedLatencyMs: 31,
      underruns: 2,
      overloadEvents: 3,
    );
    when(() => engine.stats()).thenReturn(const Ok(stats));
    expect(GetEngineStats(engine)(), const Ok(stats));
  });

  test('propagates Err', () {
    when(
      () => engine.stats(),
    ).thenReturn(const Err(EngineStateFailure('disposed')));
    expect(
      GetEngineStats(engine)(),
      const Err<EngineStats>(EngineStateFailure('disposed')),
    );
  });
}
