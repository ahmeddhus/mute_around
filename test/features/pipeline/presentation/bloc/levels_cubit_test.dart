import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_audio_levels.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/levels_cubit.dart';

class MockWatchAudioLevels extends Mock implements WatchAudioLevels {}

void main() {
  late MockWatchAudioLevels watch;
  late StreamController<AudioLevels> levels;

  setUp(() {
    watch = MockWatchAudioLevels();
    levels = StreamController<AudioLevels>.broadcast();
    when(watch.call).thenAnswer((_) => levels.stream);
  });
  tearDown(() => levels.close());

  test('starts silent', () async {
    final cubit = LevelsCubit(watch);
    expect(cubit.state, AudioLevels.silent);
    await cubit.close();
  });

  blocTest<LevelsCubit, AudioLevels>(
    'emits each polled reading',
    build: () => LevelsCubit(watch),
    act: (_) {
      levels
        ..add(const AudioLevels(inputPeakDb: -12, outputPeakDb: -40))
        ..add(const AudioLevels(inputPeakDb: -6, outputPeakDb: -20));
    },
    expect: () => const [
      AudioLevels(inputPeakDb: -12, outputPeakDb: -40),
      AudioLevels(inputPeakDb: -6, outputPeakDb: -20),
    ],
  );

  blocTest<LevelsCubit, AudioLevels>(
    'goes quiet while the source pauses (window hidden)',
    build: () => LevelsCubit(watch),
    act: (_) async {
      levels.add(const AudioLevels(inputPeakDb: -12));
      // Hidden: the data source stops polling, so nothing arrives.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    expect: () => const [AudioLevels(inputPeakDb: -12)],
  );

  test('close cancels the subscription', () async {
    final cubit = LevelsCubit(watch);
    expect(levels.hasListener, isTrue);
    await cubit.close();
    expect(levels.hasListener, isFalse);
  });
}
