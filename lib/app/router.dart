import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/diagnostics_cubit.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/levels_cubit.dart';
import 'package:mute_around/features/pipeline/presentation/pages/about_page.dart';
import 'package:mute_around/features/pipeline/presentation/pages/home_page.dart';
import 'package:mute_around/features/setup/presentation/bloc/setup_cubit.dart';
import 'package:mute_around/features/setup/presentation/pages/setup_page.dart';

part 'router.g.dart';

/// Main screen.
@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  /// The meters' cubit lives with this route.
  @override
  Widget build(BuildContext context, GoRouterState state) => BlocProvider(
    create: (context) => context.read<LevelsCubitFactory>().create(),
    child: const HomePage(),
  );
}

/// First-run setup: microphone permission and virtual microphone.
@TypedGoRoute<SetupRoute>(path: '/setup')
class SetupRoute extends GoRouteData with $SetupRoute {
  const SetupRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const SetupPage();
}

/// About, licenses and diagnostics.
@TypedGoRoute<AboutRoute>(path: '/about')
class AboutRoute extends GoRouteData with $AboutRoute {
  const AboutRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => BlocProvider(
    create: (context) => context.read<DiagnosticsCubitFactory>().create(),
    child: const AboutPage(),
  );
}

/// Builds the app's router. [setup] drives the first-run redirect, which
/// re-runs whenever [refresh] notifies (a `StreamListenable` over
/// `setup.stream`, owned and disposed by the caller).
GoRouter createRouter({
  required SetupCubit setup,
  required Listenable refresh,
}) => GoRouter(
  routes: $appRoutes,
  refreshListenable: refresh,
  redirect: (context, state) => setupRedirect(setup.state, state.uri.path),
);

/// The first-run redirect:
/// - Home goes to Setup until the virtual mic is ready and permission
///   allows processing (Windows `notDetermined` passes).
/// - Setup goes Home once everything is ready, where processing starts.
/// - Nothing moves before the first check finishes, or on About.
String? setupRedirect(SetupState state, String path) {
  if (!state.isChecked) return null;
  final home = const HomeRoute().location;
  final setup = const SetupRoute().location;
  if (!state.isReady && path == home) return setup;
  if (state.isReady && path == setup) return home;
  return null;
}
