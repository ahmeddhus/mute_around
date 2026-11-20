import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';

/// What the pipeline is doing, in plain words.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.status});

  final PipelineStatus status;

  /// The banner text for [status]; also used by the tray.
  static String label(PipelineStatus status) => switch (status) {
    Starting() => 'Starting…',
    Processing() => 'Processing',
    Bypassed(reason: BypassReason.user) => 'Bypassed',
    Bypassed(reason: BypassReason.overload) => 'Bypassed — computer too busy',
    DeviceDisconnected() => 'Microphone disconnected',
    NoInputDevice() => 'No microphone',
    SetupRequired() => 'Setup needed',
    PermissionNeeded() => 'Microphone access needed',
    EngineError() => 'Something went wrong',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (status) {
      Processing() => (
        Icons.graphic_eq,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      Starting() || Bypassed() => (
        status is Starting ? Icons.hourglass_top : Icons.mic_none,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      _ => (
        Icons.error_outline,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };
    return Semantics(
      liveRegion: true,
      child: Card(
        color: background,
        child: Padding(
          padding: const .all(16),
          child: Row(
            spacing: 12,
            children: [
              Icon(icon, color: foreground),
              Expanded(
                child: Text(
                  label(status),
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
