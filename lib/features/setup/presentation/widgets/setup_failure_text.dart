import 'package:mute_around/core/failures.dart';

/// Plain-language text for a setup action that failed.
String setupFailureText(Failure failure) => switch (failure) {
  InstallFailure() =>
    'The Mute Around microphone could not be installed. Rebuild the app '
        'and try again, or install it by hand with dev_install.sh.',
  UserCancelled() => 'Cancelled.',
  _ =>
    'Something went wrong. Try again, or open the settings yourself. '
        '(${failure.detail})',
};
