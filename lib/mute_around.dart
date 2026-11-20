import 'package:material_ui/material_ui.dart';
import 'package:mute_around/home_page.dart';

class MuteAround extends StatelessWidget {
  const MuteAround({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mute Around',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const HomePage(title: 'Mute Around Home Page'),
    );
  }
}
