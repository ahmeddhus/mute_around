import 'package:material_ui/material_ui.dart';
import 'package:mute_around/features/settings/domain/entities/processing_settings.dart';

/// Bypass, noise-suppression strength and auto gain.
/// All take effect within 100 ms without interrupting the virtual mic.
class ProcessingControls extends StatelessWidget {
  const ProcessingControls({
    super.key,
    required this.userBypass,
    required this.strength,
    required this.agcEnabled,
    required this.onBypassChanged,
    required this.onStrengthChanged,
    required this.onAgcChanged,
  });

  final bool userBypass;
  final SuppressionStrength strength;
  final bool agcEnabled;
  final ValueChanged<bool> onBypassChanged;
  final ValueChanged<SuppressionStrength> onStrengthChanged;
  final ValueChanged<bool> onAgcChanged;

  static String strengthLabel(SuppressionStrength s) => switch (s) {
    .low => 'Low',
    .medium => 'Medium',
    .high => 'High',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .stretch,
      children: [
        SwitchListTile(
          title: const Text('Bypass (hear raw mic)'),
          subtitle: const Text('Turn processing off without disconnecting.'),
          value: userBypass,
          onChanged: onBypassChanged,
        ),
        ListTile(
          title: const Text('Noise reduction'),
          subtitle: Padding(
            padding: const .only(top: 8),
            child: SegmentedButton<SuppressionStrength>(
              segments: [
                for (final s in SuppressionStrength.values)
                  ButtonSegment(
                    value: s,
                    label: Text(strengthLabel(s)),
                    tooltip: 'Removes up to ${s.maxAttenuationDb} dB of noise',
                  ),
              ],
              selected: {strength},
              onSelectionChanged: (s) => onStrengthChanged(s.single),
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Auto gain'),
          subtitle: const Text('Keeps your voice at a steady volume.'),
          value: agcEnabled,
          onChanged: onAgcChanged,
        ),
      ],
    );
  }
}
