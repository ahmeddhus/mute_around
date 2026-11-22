import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mute_around/core/app_version.dart';
import 'package:mute_around/features/pipeline/domain/entities/engine_stats.dart';
import 'package:mute_around/features/pipeline/presentation/bloc/diagnostics_cubit.dart';

/// About, licenses and diagnostics.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final version = context.read<AppVersion>().text;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About Mute Around')),
      body: ListView(
        padding: const .all(16),
        children: [
          Text('Mute Around', style: text.headlineSmall),
          Text('Version $version'),
          const SizedBox(height: 8),
          const Text(
            'Removes background noise from your microphone, on this '
            'computer. Audio never leaves it, and nothing is recorded.',
          ),
          const SizedBox(height: 8),
          Align(
            alignment: .centerLeft,
            child: OutlinedButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'Mute Around',
                applicationVersion: version,
              ),
              child: const Text('Open-source licenses'),
            ),
          ),
          const SizedBox(height: 24),
          Text('Diagnostics', style: text.titleMedium),
          BlocBuilder<DiagnosticsCubit, EngineStats?>(
            builder: (context, stats) => _Diagnostics(stats: stats),
          ),
        ],
      ),
    );
  }
}

class _Diagnostics extends StatelessWidget {
  const _Diagnostics({required this.stats});

  final EngineStats? stats;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    if (s == null) return const Text('The audio engine has not started.');
    final rows = <(String, String)>[
      (
        'Added delay (estimate)',
        s.estimatedLatencyMs > 0
            ? '${s.estimatedLatencyMs.toStringAsFixed(1)} ms'
            : 'not running',
      ),
      (
        'Processing time per 10 ms',
        '${s.avgProcessMs.toStringAsFixed(2)} ms',
      ),
      ('Frames processed', '${s.framesProcessed}'),
      ('Output underruns', '${s.underruns}'),
      ('Times too busy (auto-bypass)', '${s.overloadEvents}'),
    ];
    return Column(
      children: [
        for (final (label, value) in rows)
          ListTile(dense: true, title: Text(label), trailing: Text(value)),
      ],
    );
  }
}
