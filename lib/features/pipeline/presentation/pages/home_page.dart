import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/app/router.dart';
import 'package:mute_around/core/failures.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/pipeline/domain/entities/audio_levels.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/levels_cubit.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/error_card.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/input_device_dropdown.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/level_meter.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/meeting_app_hint.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/processing_controls.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/status_banner.dart';

/// Main screen. Reads the app-scoped [PipelineBloc] and
/// the route-scoped [LevelsCubit].
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final platform = context.read<HostInfo>().platform;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mute Around'),
        actions: [
          IconButton(
            tooltip: 'About',
            icon: const Icon(Icons.info_outline),
            onPressed: () => const AboutRoute().push<void>(context),
          ),
        ],
      ),
      body: ListView(
        padding: const .all(16),
        children: [
          const _Status(),
          const SizedBox(height: 16),
          const _DevicePicker(),
          const SizedBox(height: 24),
          BlocBuilder<LevelsCubit, AudioLevels>(
            builder: (context, levels) => LevelMeters(levels: levels),
          ),
          const SizedBox(height: 16),
          const _Controls(),
          const SizedBox(height: 16),
          MeetingAppHint(platform: platform),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      PipelineBloc,
      PipelineState,
      (PipelineStatus, Failure?)
    >(
      selector: (state) => (state.status, state.controlFailure),
      builder: (context, selected) {
        final (status, controlFailure) = selected;
        final bloc = context.read<PipelineBloc>();
        return Column(
          crossAxisAlignment: .stretch,
          spacing: 8,
          children: [
            StatusBanner(status: status),
            switch (status) {
              EngineError(:final failure) => ErrorCard(
                failure: failure,
                actionLabel: 'Try again',
                onAction: () => bloc.add(const PipelineEvent.retryRequested()),
              ),
              SetupRequired() || PermissionNeeded() => Align(
                alignment: .centerLeft,
                child: FilledButton.tonal(
                  onPressed: () => const SetupRoute().go(context),
                  child: const Text('Open setup'),
                ),
              ),
              _ => const SizedBox.shrink(),
            },
            if (controlFailure != null) ErrorCard(failure: controlFailure),
          ],
        );
      },
    );
  }
}

class _DevicePicker extends StatelessWidget {
  const _DevicePicker();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PipelineBloc, PipelineState>(
      buildWhen: (a, b) =>
          a.devices != b.devices || a.selectedDeviceId != b.selectedDeviceId,
      builder: (context, state) => InputDeviceDropdown(
        devices: state.devices,
        selectedId: state.selectedDeviceId,
        onSelected: (id) =>
            context.read<PipelineBloc>().add(PipelineEvent.inputSelected(id)),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PipelineBloc, PipelineState>(
      buildWhen: (a, b) =>
          a.userBypass != b.userBypass ||
          a.strength != b.strength ||
          a.agcEnabled != b.agcEnabled,
      builder: (context, state) {
        final bloc = context.read<PipelineBloc>();
        return ProcessingControls(
          userBypass: state.userBypass,
          strength: state.strength,
          agcEnabled: state.agcEnabled,
          onBypassChanged: (on) =>
              bloc.add(PipelineEvent.bypassToggled(enabled: on)),
          onStrengthChanged: (s) => bloc.add(PipelineEvent.strengthChanged(s)),
          onAgcChanged: (on) => bloc.add(PipelineEvent.agcToggled(enabled: on)),
        );
      },
    );
  }
}
