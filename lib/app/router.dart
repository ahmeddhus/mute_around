import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/presentation/pages/about_page.dart';
import 'package:mute_around/features/pipeline/presentation/pages/home_page.dart';
import 'package:mute_around/features/setup/presentation/pages/setup_page.dart';

part 'router.g.dart';

/// Main screen.
@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomePage();
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
  Widget build(BuildContext context, GoRouterState state) => const AboutPage();
}

/// Builds the app's router.
GoRouter createRouter() => GoRouter(routes: $appRoutes);
