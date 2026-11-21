import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';

/// What the pipeline is doing, in plain words.
/// Status changes are announced to screen readers.
class StatusBanner extends StatefulWidget {
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
  State<StatusBanner> createState() => _StatusBannerState();
}

class _StatusBannerState extends State<StatusBanner> {
  @override
  void didUpdateWidget(StatusBanner old) {
    super.didUpdateWidget(old);
    final text = StatusBanner.label(widget.status);
    if (text != StatusBanner.label(old.status)) {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          text,
          Directionality.of(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
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
                  StatusBanner.label(status),
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
