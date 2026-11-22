import 'dart:async';

import 'package:flutter/foundation.dart';

/// Adapts a [Stream] to a [Listenable] for `GoRouter.refreshListenable`, so
/// the redirect re-runs whenever the stream emits (e.g. `SetupCubit.stream`),
/// not only on navigation.
class StreamListenable extends ChangeNotifier {
  StreamListenable(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
