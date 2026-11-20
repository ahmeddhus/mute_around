import 'dart:ui' show AppExitResponse;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/app/router.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/pipeline/domain/usecases/stop_pipeline.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';

/// The root widget.
///
/// Provides the app-scoped blocs above the router, so navigating never
/// closes them and the engine keeps running for the whole app lifetime.
/// Dependencies come from `main.dart`, the
/// composition root, which keeps this widget testable with fakes.
class MuteAround extends StatefulWidget {
  const MuteAround({
    super.key,
    required this.createPipelineBloc,
    required this.stopPipeline,
    required this.hostInfo,
  });

  final PipelineBloc Function() createPipelineBloc;
  final StopPipeline stopPipeline;
  final HostInfo hostInfo;

  @override
  State<MuteAround> createState() => _MuteAroundState();
}

class _MuteAroundState extends State<MuteAround> {
  late final GoRouter _router = createRouter();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
  }

  /// The single exit path: stop the engine so the virtual mic goes
  /// silent, then let the app quit. Hiding the window is not an exit,
  /// so `hidden`/`inactive`/`paused` are deliberately not handled.
  Future<AppExitResponse> _onExitRequested() async {
    await widget.stopPipeline();
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: widget.hostInfo,
      child: BlocProvider(
        // Until the setup flow reports readiness, the virtual mic
        // is installed by hand, so readiness is sent once at launch; a
        // missing sink still surfaces as SetupRequired via StartPipeline.
        create: (_) =>
            widget.createPipelineBloc()
              ..add(const PipelineEvent.readinessChanged(ready: true)),
        lazy: false,
        child: MaterialApp.router(
          title: 'Mute Around',
          theme: ThemeData(
            colorScheme: .fromSeed(seedColor: Colors.deepPurple),
          ),
          darkTheme: ThemeData(
            colorScheme: .fromSeed(
              seedColor: Colors.deepPurple,
              brightness: .dark,
            ),
          ),
          routerConfig: _router,
        ),
      ),
    );
  }
}
