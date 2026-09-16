import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/lobby_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive fullscreen and landscape orientation for FPS gaming experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  runApp(const UrsinaMultiplayerApp());
}

class UrsinaMultiplayerApp extends StatelessWidget {
  const UrsinaMultiplayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ursina FPS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF010D25),
        colorScheme: const ColorScheme.dark(
          primary: Colors.lightBlueAccent,
          secondary: Colors.cyanAccent,
        ),
      ),
      home: const LobbyScreen(),
    );
  }
}
