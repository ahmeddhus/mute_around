import 'package:material_ui/material_ui.dart';
import 'package:mute_around/app/app.dart';
import 'package:mute_around/app/di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(
    MuteAround(
      createPipelineBloc: getIt.call,
      stopPipeline: getIt(),
      hostInfo: getIt(),
    ),
  );
}
