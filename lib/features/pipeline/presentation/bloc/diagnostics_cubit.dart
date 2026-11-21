import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:mute_around/features/pipeline/domain/entities/engine_stats.dart';
import 'package:mute_around/features/pipeline/domain/usecases/get_engine_stats.dart';

/// Engine diagnostics for the About page, refreshed every [interval] while
/// the page is open. `null` until the engine has reported once.
@injectable
class DiagnosticsCubit extends Cubit<EngineStats?> {
  DiagnosticsCubit(
    this._getStats, {
    @ignoreParam Duration interval = const Duration(seconds: 1),
  }) : super(null) {
    _refresh();
    _timer = Timer.periodic(interval, (_) => _refresh());
  }

  final GetEngineStats _getStats;
  late final Timer _timer;

  void _refresh() {
    if (_getStats().valueOrNull case final stats?) emit(stats);
  }

  @override
  Future<void> close() {
    _timer.cancel();
    return super.close();
  }
}

/// Creates the route-scoped [DiagnosticsCubit] (see `LevelsCubitFactory`).
final class DiagnosticsCubitFactory {
  const DiagnosticsCubitFactory(this.create);

  final DiagnosticsCubit Function() create;
}
