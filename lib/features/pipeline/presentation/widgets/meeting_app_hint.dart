import 'package:material_ui/material_ui.dart';
import 'package:mute_around/core/platform.dart';

/// Tells the user which microphone to pick in Zoom, Slack, Teams, …
class MeetingAppHint extends StatelessWidget {
  const MeetingAppHint({super.key, required this.platform});

  final HostPlatform platform;

  /// The device name meeting apps list for our virtual microphone.
  static String deviceName(HostPlatform platform) => switch (platform) {
    .macos => 'Mute Around',
    .windows => 'CABLE Output',
  };

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'In your meeting app, choose '),
          TextSpan(
            text: deviceName(platform),
            style: const TextStyle(fontWeight: .bold),
          ),
          const TextSpan(text: ' as the microphone.'),
        ],
      ),
    );
  }
}
