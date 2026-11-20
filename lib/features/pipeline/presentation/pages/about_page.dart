import 'package:material_ui/material_ui.dart';

/// About, licenses and diagnostics. Placeholder until Polish.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Mute Around')),
      body: Center(
        child: TextButton(
          onPressed: () => showLicensePage(context: context),
          child: const Text('Licenses'),
        ),
      ),
    );
  }
}
