import 'package:material_ui/material_ui.dart';
import 'package:mute_around/core/failures.dart';

/// What to tell the user about a [Failure]: a plain-language title and the
/// suggested fix. The technical detail is kept for diagnostics.
({String title, String message}) describeFailure(Failure failure) =>
    switch (failure) {
      PermissionDenied() => (
        title: 'Microphone access is off',
        message:
            'Allow Mute Around to use the microphone in your system privacy '
            'settings, then come back.',
      ),
      DeviceNotFound() => (
        title: 'Microphone not found',
        message: 'Plug it back in or choose another microphone.',
      ),
      DeviceFailure() => (
        title: "The microphone couldn't be opened",
        message:
            'Another app may be using it exclusively. Close that app or pick '
            'another microphone, then try again.',
      ),
      ModelLoadFailure() => (
        title: "Noise reduction couldn't start",
        message: 'The app may be damaged. Rebuild or reinstall it.',
      ),
      EngineStateFailure() => (
        title: 'The audio engine needs a restart',
        message: 'Try again. If it keeps happening, quit and reopen the app.',
      ),
      VirtualMicMissing() => (
        title: 'The virtual microphone is missing',
        message: 'Open setup to install it again.',
      ),
      UserCancelled() => (title: 'Cancelled', message: 'Nothing was changed.'),
      InstallFailure() => (
        title: "The virtual microphone couldn't be installed",
        message: 'Try again from setup.',
      ),
      UnknownFailure() => (
        title: 'Something went wrong',
        message: 'Try again. If it keeps happening, quit and reopen the app.',
      ),
    };

/// A plain-language error with an optional action button.
class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.failure,
    this.actionLabel,
    this.onAction,
  });

  final Failure failure;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (:title, :message) = describeFailure(failure);
    final label = actionLabel;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: scheme.errorContainer,
        child: Padding(
          padding: const .all(16),
          child: Column(
            crossAxisAlignment: .start,
            spacing: 8,
            children: [
              Text(
                title,
                style: text.titleSmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
              Text(
                message,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
              if (failure.detail.isNotEmpty)
                Text(
                  failure.detail,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              if (label != null && onAction != null)
                FilledButton.tonal(onPressed: onAction, child: Text(label)),
            ],
          ),
        ),
      ),
    );
  }
}
