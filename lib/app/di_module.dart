import 'package:injectable/injectable.dart';
import 'package:mute_around/core/platform.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Third-party and platform objects that can't carry injectable annotations.
@module
abstract class AppModule {
  /// Settings storage; created and ready before the first `getIt` read.
  @preResolve
  @lazySingleton
  Future<SharedPreferencesAsync> get prefs async => SharedPreferencesAsync();
}

/// The platform the app is running on, resolved once.
@module
abstract class PlatformModule {
  @lazySingleton
  HostInfo get hostInfo => HostInfo(currentHostPlatform());
}
