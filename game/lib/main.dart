import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/audio_service.dart';
import 'ui/lobby_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive fullscreen and landscape orientation for FPS gaming experience
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Pre-initialize audio system
  await AudioService.initialize();

  runApp(const UrsinaMultiplayerApp());
}

class UrsinaMultiplayerApp extends StatefulWidget {
  const UrsinaMultiplayerApp({super.key});

  @override
  State<UrsinaMultiplayerApp> createState() => _UrsinaMultiplayerAppState();
}

class _UrsinaMultiplayerAppState extends State<UrsinaMultiplayerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      AudioService.pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      AudioService.resumeMusic();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deathmatch 3D',
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
