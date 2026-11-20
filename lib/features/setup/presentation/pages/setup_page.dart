import 'package:material_ui/material_ui.dart';

/// First-run setup screen. Placeholder for now.
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up Mute Around')),
      body: const Center(child: Text('Setup')),
    );
  }
}
