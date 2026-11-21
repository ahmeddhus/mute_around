import 'package:injectable/injectable.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a URL in another app (System Settings, the browser). The app itself
/// makes no network request.
abstract interface class ExternalLinksDataSource {
  /// Returns whether something opened [uri].
  Future<bool> open(Uri uri);
}

@LazySingleton(as: ExternalLinksDataSource)
class UrlLauncherLinksDataSource implements ExternalLinksDataSource {
  const UrlLauncherLinksDataSource();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: .externalApplication);
    } on Object {
      // launchUrl throws PlatformException for unsupported schemes.
      return false;
    }
  }
}
