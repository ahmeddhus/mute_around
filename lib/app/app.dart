import 'dart:async';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/app/router.dart';
import 'package:mute_around/app/router_refresh.dart';
import 'package:mute_around/app/tray/desktop_shell.dart';
import 'package:mute_around/app/tray/tray_controller.dart';
import 'package:mute_around/app/tray/window_behavior.dart';
import 'package:mute_around/core/app_version.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/domain/usecases/stop_pipeline.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/diagnostics_cubit.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/levels_cubit.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/settings/domain/usecases/flush_settings.dart';
import 'package:mute_around/features/setup/presentation/bloc/setup_cubit.dart';

/// The root widget.
///
/// Owns the app-scoped [PipelineBloc] and [SetupCubit] above the router, so
/// navigating never closes them and the engine keeps running for the whole
/// app lifetime. The two never reference each
/// other: the listeners here connect them. Dependencies come from
/// `main.dart`, the composition root, which keeps this widget testable.
class MuteAround extends StatefulWidget {
  const MuteAround({
    super.key,
    required this.createPipelineBloc,
    required this.createSetupCubit,
    required this.createLevelsCubit,
    required this.createDiagnosticsCubit,
    required this.appVersion,
    required this.stopPipeline,
    required this.flushSettings,
    required this.hostInfo,
    this.shell,
  });

  final PipelineBloc Function() createPipelineBloc;
  final SetupCubit Function() createSetupCubit;
  final LevelsCubit Function() createLevelsCubit;
  final DiagnosticsCubit Function() createDiagnosticsCubit;
  final AppVersion appVersion;
  final StopPipeline stopPipeline;
  final FlushSettings flushSettings;
  final HostInfo hostInfo;

  /// Tray icon and hide-to-tray; `null` in widget tests.
  final DesktopShell? shell;

  @override
  State<MuteAround> createState() => _MuteAroundState();
}

class _MuteAroundState extends State<MuteAround> {
  late final PipelineBloc _pipeline = widget.createPipelineBloc();
  late final SetupCubit _setup = widget.createSetupCubit();
  late final StreamListenable _routerRefresh = StreamListenable(
    _setup.stream,
  );
  late final GoRouter _router = createRouter(
    setup: _setup,
    refresh: _routerRefresh,
  );
  late final AppLifecycleListener _lifecycle;
  TrayController? _tray;

  @override
  void initState() {
    super.initState();
    final shell = widget.shell;
    _lifecycle = AppLifecycleListener(
      onExitRequested: _onExitRequested,
      // Back from System Settings / the VB-CABLE installer.
      onResume: () => unawaited(_setup.appResumed()),
      // Minimised or hidden: poll slower and pause the meters.
      onHide: () => shell?.setUiVisible(visible: false),
      onShow: () => shell?.setUiVisible(visible: true),
    );
    if (shell != null) {
      final window = WindowBehavior(shell.window, shell.setUiVisible)..init();
      _tray = TrayController(
        host: shell.tray,
        pipeline: _pipeline,
        onOpen: window.showWindow,
        // Quit goes through the single exit path below.
        onQuit: () => unawaited(
          ServicesBinding.instance.exitApplication(AppExitType.cancelable),
        ),
      )..start();
    }
    unawaited(_setup.recheck());
  }

  /// The single exit path: stop the engine so the virtual mic goes
  /// silent, write any debounced settings, then let the app quit.
  /// Hiding the window is not an exit, so `hidden`/`inactive`/`paused`
  /// are deliberately not handled.
  Future<AppExitResponse> _onExitRequested() async {
    await widget.stopPipeline();
    await widget.flushSettings();
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    unawaited(_tray?.dispose());
    _lifecycle.dispose();
    _router.dispose();
    _routerRefresh.dispose();
    unawaited(_setup.close());
    unawaited(_pipeline.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget.hostInfo),
        RepositoryProvider.value(value: widget.appVersion),
        RepositoryProvider.value(
          value: LevelsCubitFactory(widget.createLevelsCubit),
        ),
        RepositoryProvider.value(
          value: DiagnosticsCubitFactory(widget.createDiagnosticsCubit),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _pipeline),
          BlocProvider.value(value: _setup),
        ],
        child: MultiBlocListener(
          listeners: [
            // Readiness → pipeline: processing starts once setup is ready
            // and stops if the virtual mic disappears.
            BlocListener<SetupCubit, SetupState>(
              listenWhen: (previous, current) =>
                  current.isChecked &&
                  (!previous.isChecked || previous.isReady != current.isReady),
              listener: (context, state) => _pipeline.add(
                PipelineEvent.readinessChanged(ready: state.isReady),
              ),
            ),
            // Pipeline → setup: the engine found the sink missing or was
            // refused the microphone, so setup re-checks (and redirects).
            BlocListener<PipelineBloc, PipelineState>(
              listenWhen: (previous, current) =>
                  previous.status.runtimeType != current.status.runtimeType,
              listener: (context, state) => switch (state.status) {
                SetupRequired() => unawaited(_setup.recheck()),
                PermissionNeeded() => unawaited(
                  _setup.engineReportedPermissionDenied(),
                ),
                _ => null,
              },
            ),
          ],
          child: MaterialApp.router(
            title: 'Mute Around',
            debugShowCheckedModeBanner: false,
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
      ),
    );
  }
}
