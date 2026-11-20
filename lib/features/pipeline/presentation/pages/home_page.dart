import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/app/router.dart';
import 'package:mute_around/core/platform.dart';
import 'package:mute_around/features/pipeline/domain/entities/pipeline_status.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/pipeline_bloc.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/meeting_app_hint.dart';
import 'package:mute_around/features/pipeline/presentation/widgets/status_banner.dart';

/// Main screen. Reads the app-scoped [PipelineBloc].
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
            onPressed: () => const AboutRoute().go(context),
          ),
        ],
      ),
      body: ListView(
        padding: const .all(16),
        children: [
          BlocSelector<PipelineBloc, PipelineState, PipelineStatus>(
            selector: (state) => state.status,
            builder: (context, status) => Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                StatusBanner(status: status),
                if (status is EngineError)
                  Align(
                    alignment: .centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                      onPressed: () => context.read<PipelineBloc>().add(
                        const PipelineEvent.retryRequested(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          MeetingAppHint(platform: platform),
        ],
      ),
    );
  }
}
