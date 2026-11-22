import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/app/router.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/setup/domain/entities/mic_permission.dart';
import 'package:mute_around/features/setup/domain/entities/virtual_mic_status.dart';
import 'package:mute_around/features/setup/presentation/bloc/setup_cubit.dart';
import 'package:mute_around/features/setup/presentation/widgets/setup_failure_text.dart';
import 'package:mute_around/features/setup/presentation/widgets/setup_step.dart';

/// First-run setup: microphone access, then the
/// virtual microphone. Reads the app-scoped [SetupCubit]; the router sends
/// the user Home once everything is ready.
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final platform = context.read<HostInfo>().platform;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up Mute Around'),
        actions: [
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => const AboutRoute().push<void>(context),
          ),
        ],
      ),
      body: BlocBuilder<SetupCubit, SetupState>(
        builder: (context, state) {
          final readiness = state.readiness;
          if (readiness == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const .all(16),
            children: [
              Text(
                'Mute Around needs two things before it can clean up your '
                'voice.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              _PermissionStep(
                platform: platform,
                permission: readiness.permission,
                busy: state.activity == .requestingPermission,
              ),
              _VirtualMicStep(
                platform: platform,
                status: readiness.virtualMic,
                busy: state.activity == .installing,
              ),
              if (state.failure case final failure?)
                Padding(
                  padding: const .symmetric(vertical: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      setupFailureText(failure),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: .centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Check again'),
                  onPressed: () => unawaited(
                    context.read<SetupCubit>().recheck(userInitiated: true),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.platform,
    required this.permission,
    required this.busy,
  });

  final HostPlatform platform;
  final MicPermission permission;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SetupCubit>();
    final openSettings = TextButton(
      onPressed: () => unawaited(cubit.openPrivacySettings()),
      child: const Text('Open privacy settings'),
    );
    final (done, description, actions) = switch ((platform, permission)) {
      (_, .granted) => (
        true,
        'Mute Around can use your microphone.',
        <Widget>[],
      ),
      (.windows, .notDetermined) => (
        true,
        'Windows asks when Mute Around first uses the microphone.',
        <Widget>[],
      ),
      (.macos, .notDetermined) => (
        false,
        'Mute Around needs to hear your microphone to clean it up. Audio '
            'never leaves this computer.',
        <Widget>[
          FilledButton(
            onPressed: busy ? null : () => unawaited(cubit.requestPermission()),
            child: const Text('Grant access'),
          ),
        ],
      ),
      (_, .denied) => (
        false,
        switch (platform) {
          .macos =>
            'Microphone access is turned off. In System Settings → Privacy & '
                'Security → Microphone, turn on Mute Around, then come back.',
          .windows =>
            'Windows blocked the microphone. In Settings → Privacy → '
                'Microphone, allow desktop apps to use it, then come back.',
        },
        <Widget>[openSettings],
      ),
    };
    return SetupStep(
      number: 1,
      title: 'Microphone access',
      done: done,
      description: description,
      actions: actions,
    );
  }
}

class _VirtualMicStep extends StatelessWidget {
  const _VirtualMicStep({
    required this.platform,
    required this.status,
    required this.busy,
  });

  final HostPlatform platform;
  final VirtualMicStatus status;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SetupCubit>();
    final ready = status is VirtualMicReady;
    final description = switch ((platform, status)) {
      (.macos, VirtualMicReady()) => 'The Mute Around microphone is installed.',
      (.windows, VirtualMicReady()) => 'VB-CABLE is installed.',
      (_, VirtualMicUnknown()) =>
        "The audio devices couldn't be listed. Check again in a moment.",
      (.macos, _) =>
        'Mute Around adds a microphone called "Mute Around" that meeting '
            'apps can pick. Installing it asks for your administrator '
            'password once.',
      (.windows, _) =>
        'On Windows, Mute Around sends your cleaned voice through VB-CABLE, '
            'a free virtual audio cable. Download and install it, restart '
            'if asked, then come back: Mute Around finds it on its own.',
    };
    final actions = <Widget>[
      if (!ready && platform == .macos)
        FilledButton.icon(
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: const Text('Install Mute Around microphone'),
          onPressed: busy ? null : () => unawaited(cubit.installVirtualMic()),
        ),
      if (!ready && platform == .windows)
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: const Text('Download VB-CABLE'),
          onPressed: () => unawaited(cubit.openVirtualMicDownload()),
        ),
    ];
    return SetupStep(
      number: 2,
      title: 'Virtual microphone',
      done: ready,
      description: description,
      actions: actions,
    );
  }
}
