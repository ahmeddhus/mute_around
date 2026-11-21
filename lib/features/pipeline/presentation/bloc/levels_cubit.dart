import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';
import 'package:mute_around/features/pipeline/domain/usecases/watch_audio_levels.dart';

/// Live meter levels, kept apart from `PipelineBloc` so 30 Hz
/// meter updates only rebuild the meters, not the page.
///
/// Route-scoped on Home. Levels arrive at most 30 times a second; the
/// engine data source stops polling while the window is hidden, so this
/// cubit simply goes quiet.
@injectable
class LevelsCubit extends Cubit<AudioLevels> {
  LevelsCubit(WatchAudioLevels watchLevels) : super(AudioLevels.silent) {
    _subscription = watchLevels().listen(emit);
  }

  late final StreamSubscription<AudioLevels> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

/// Creates the route-scoped [LevelsCubit]; provided by the app so Home's
/// route doesn't reach for the service locator (and tests can fake it).
final class LevelsCubitFactory {
  const LevelsCubitFactory(this.create);

  final LevelsCubit Function() create;
}
