import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:mute_around/app/di.config.dart';

/// The app's service locator. Only widgets (via `BlocProvider`) and this
/// composition root read it; everything else uses constructor injection.
final GetIt getIt = GetIt.instance;

/// Registers every `@injectable` class. Call once, in `main`.
@InjectableInit()
Future<void> configureDependencies({String? environment}) async {
  await getIt.init(environment: environment);
}
