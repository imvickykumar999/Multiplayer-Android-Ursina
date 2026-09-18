import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enemy.dart';
import '../models/player.dart';
import '../models/map_data.dart';
import '../services/network.dart';
import '../services/audio_service.dart';
import 'game_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _serverController =
      TextEditingController(text: 'game.24x7stream.shop');
  final TextEditingController _portController =
      TextEditingController(text: '8888');

  String _currentColorName = 'Blue';
  Color _currentColor = const Color.fromARGB(255, 52, 152, 219);
  bool _isConnecting = false;
  String? _errorMessage;
  bool? _isServerOnline;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _currentColorName = colorNames[rnd.nextInt(colorNames.length)];
    _currentColor = colorPalette[_currentColorName]!;
    _usernameController.text = _currentColorName;

    _usernameController.addListener(_onUsernameChanged);

    // Ensure background music starts seamlessly and consistently
    AudioService.playMusic();

    // Fast probe to check server status
    _checkServerStatus();
  }

  Future<void> _checkServerStatus() async {
    final host = _serverController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8888;
    try {
      final s = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 2000),
      );
      s.destroy();
      if (mounted) {
        setState(() => _isServerOnline = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isServerOnline = false);
      }
    }
  }

  void _onUsernameChanged() {
    final text = _usernameController.text.trim();
    setState(() {
      _currentColor = getPlayerColor('1', text);
      final match = colorPalette.entries.firstWhere(
        (e) => e.key.toLowerCase() == text.toLowerCase(),
        orElse: () => MapEntry(text.isEmpty ? 'Custom' : text, _currentColor),
      );
      _currentColorName = match.key;
    });
  }

  void _selectColor(String name) {
    setState(() {
      _currentColorName = name;
      _currentColor = colorPalette[name]!;
      _usernameController.text = name;
    });
  }

  void _setServerPreset(String host, String port) {
    setState(() {
      _serverController.text = host;
      _portController.text = port;
      _isServerOnline = null;
    });
    _checkServerStatus();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _serverController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connectAndPlay() async {
    final username = _usernameController.text.trim().isEmpty
        ? 'Player'
        : _usernameController.text.trim();
    final serverAddr = _serverController.text.trim().isEmpty
        ? 'game.24x7stream.shop'
        : _serverController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8888;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final network = NetworkService(
      serverAddr: serverAddr,
      serverPort: port,
      username: username,
    );

    try {
      await network.connect();

      if (!mounted) return;

      final rnd = Random();
      final spawnPos =
          MapData.spawnPoints[rnd.nextInt(MapData.spawnPoints.length)];
      final localPlayer = Player(
        startPos: spawnPos,
        id: network.id,
        username: username,
        color: _currentColor,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            network: network,
            player: localPlayer,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _isServerOnline = false;
        _errorMessage =
            'Could not connect to $serverAddr:$port. You can play offline against AI bots!';
      });
    }
  }

  Future<void> _playOfflinePractice() async {
    final username = _usernameController.text.trim().isEmpty
        ? 'Player'
        : _usernameController.text.trim();

    final network = NetworkService.offline(username: username);
    await network.connect();

    if (!mounted) return;

    final rnd = Random();
    final spawnPos =
        MapData.spawnPoints[rnd.nextInt(MapData.spawnPoints.length)];
    final localPlayer = Player(
      startPos: spawnPos,
      id: '1',
      username: username,
      color: _currentColor,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          network: network,
          player: localPlayer,
        ),
      ),
    );
  }

  void _showHowToPlayDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C192E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.sports_esports, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text('HOW TO PLAY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuideItem(Icons.touch_app, 'Movement', 'Use the virtual joystick on the bottom-left to run forward, backward, and strafe.'),
              _buildGuideItem(Icons.screen_rotation, 'Aim & Look', 'Swipe anywhere on the right half of the screen to rotate and aim.'),
              _buildGuideItem(Icons.center_focus_strong, 'ADS Scope', 'Tap the target scope button on the right to zoom in with precision reflex optic!'),
              _buildGuideItem(Icons.gps_fixed, 'Shoot', 'Tap the Red Crosshair button (or left fire button) to fire your weapon. Headshots deal 1.5x critical damage!'),
              _buildGuideItem(Icons.arrow_upward, 'Jump', 'Tap the blue jump button to leap onto obstacles, stairs, and upper walkways.'),
              _buildGuideItem(Icons.refresh, 'Reload', 'Tap the orange reload button to reload your magazine (15 rounds).'),
              _buildGuideItem(Icons.radar, 'Tactical Radar', 'Check the top-right circular minimap for arena boundaries and enemy blips with elevation markers.'),
              _buildGuideItem(Icons.smart_toy, 'Practice Bots', 'Play singleplayer offline anytime against tactical AI bots.'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('GOT IT!'),
          ),
        ],
      ),
    );
  }

  void _showAudioSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF0C192E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.lightBlueAccent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.volume_up, color: Colors.lightBlueAccent),
              SizedBox(width: 10),
              Text('AUDIO SETTINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Music Toggle & Slider
              SwitchListTile(
                title: const Text('Background Music', style: TextStyle(color: Colors.white)),
                secondary: const Icon(Icons.music_note, color: Colors.cyanAccent),
                value: AudioService.isMusicEnabled,
                activeThumbColor: Colors.cyanAccent,
                onChanged: (val) {
                  AudioService.toggleMusic();
                  setModalState(() {});
                },
              ),
              Slider(
                value: AudioService.musicVolume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                activeColor: Colors.cyanAccent,
                label: '${(AudioService.musicVolume * 100).round()}%',
                onChanged: AudioService.isMusicEnabled
                    ? (val) {
                        AudioService.setMusicVolume(val);
                        setModalState(() {});
                      }
                    : null,
              ),
              const Divider(color: Colors.white24),
              // SFX Toggle & Slider
              SwitchListTile(
                title: const Text('Sound Effects (SFX)', style: TextStyle(color: Colors.white)),
                secondary: const Icon(Icons.volume_up, color: Colors.lightBlueAccent),
                value: AudioService.isSfxEnabled,
                activeThumbColor: Colors.lightBlueAccent,
                onChanged: (val) {
                  AudioService.toggleSfx();
                  setModalState(() {});
                },
              ),
              Slider(
                value: AudioService.sfxVolume,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                activeColor: Colors.lightBlueAccent,
                label: '${(AudioService.sfxVolume * 100).round()}%',
                onChanged: AudioService.isSfxEnabled
                    ? (val) {
                        AudioService.setSfxVolume(val);
                        setModalState(() {});
                      }
                    : null,
              ),
              const SizedBox(height: 8),
              // Live Test Sound Button
              OutlinedButton.icon(
                icon: const Icon(Icons.play_circle_outline, size: 16),
                label: const Text('Test Gunshot SFX', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.lightBlueAccent,
                  side: const BorderSide(color: Colors.lightBlueAccent),
                ),
                onPressed: () => AudioService.playGunSound(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('CLOSE', style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010D25),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/background.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Container(color: const Color(0xFF010D25)),
            ),
          ),

          // Dark Sci-Fi Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    const Color(0xFF010D25).withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    // Server Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _isServerOnline == true
                            ? Colors.green.withValues(alpha: 0.2)
                            : (_isServerOnline == false
                                ? Colors.amber.withValues(alpha: 0.2)
                                : Colors.blue.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isServerOnline == true
                              ? Colors.greenAccent
                              : (_isServerOnline == false
                                  ? Colors.amberAccent
                                  : Colors.lightBlueAccent),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isServerOnline == true
                                ? Icons.wifi
                                : (_isServerOnline == false
                                    ? Icons.wifi_off
                                    : Icons.sync),
                            color: _isServerOnline == true
                                ? Colors.greenAccent
                                : (_isServerOnline == false
                                    ? Colors.amberAccent
                                    : Colors.lightBlueAccent),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isServerOnline == true
                                ? 'ONLINE (24x7stream)'
                                : (_isServerOnline == false
                                    ? 'SERVER OFFLINE (Use Bots)'
                                    : 'CHECKING SERVER...'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Audio Settings Button
                    IconButton(
                      icon: const Icon(Icons.volume_up, color: Colors.cyanAccent),
                      tooltip: 'Audio Settings',
                      onPressed: _showAudioSettingsDialog,
                    ),
                    // How to play button
                    IconButton(
                      icon: const Icon(Icons.help_outline,
                          color: Colors.cyanAccent),
                      tooltip: 'How to Play',
                      onPressed: _showHowToPlayDialog,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Center Connection Form Box
          Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 540),
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.cyanAccent.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withValues(alpha: 0.15),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 20,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.cyanAccent, Colors.lightBlueAccent],
                      ).createShader(bounds),
                      child: const Text(
                        'DEATHMATCH 3D',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Multiplayer & Bot Training 3D Arena',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Username & Avatar Row
                    Row(
                      children: [
                        // Live Player Avatar Swatch
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _currentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: _currentColor.withValues(alpha: 0.6),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        // Username Input Field
                        Expanded(
                          child: TextField(
                            controller: _usernameController,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Callsign / Username',
                              labelStyle: const TextStyle(
                                  color: Colors.lightBlueAccent, fontSize: 13),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.cyanAccent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Color Selector Chips
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Player Armor Color:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: colorNames.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final name = colorNames[idx];
                          final col = colorPalette[name]!;
                          final isSelected = _currentColorName == name;
                          return GestureDetector(
                            onTap: () => _selectColor(name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? col.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? col : Colors.white24,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: col,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Server Presets
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quick Server Select:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.public, size: 14),
                            label: const Text('Official Server',
                                style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.cyanAccent,
                              side: const BorderSide(color: Colors.cyanAccent),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () => _setServerPreset(
                                'game.24x7stream.shop', '8888'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.computer, size: 14),
                            label: const Text('Local Host',
                                style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.lightBlueAccent,
                              side: const BorderSide(
                                  color: Colors.lightBlueAccent),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () =>
                                _setServerPreset('127.0.0.1', '8888'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Server Address & Port Inputs
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _serverController,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Server IP / Domain',
                              labelStyle: const TextStyle(
                                  color: Colors.lightBlueAccent, fontSize: 12),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.cyanAccent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: _portController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Port',
                              labelStyle: const TextStyle(
                                  color: Colors.lightBlueAccent, fontSize: 12),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Colors.cyanAccent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Error Message Banner with Quick Offline Fallback button
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.redAccent, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: Colors.redAccent, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.smart_toy, size: 16),
                                label: const Text('Play Offline Bots Now',
                                    style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber[800],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                ),
                                onPressed: _playOfflinePractice,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action Buttons (Exit, Practice Bots, Join Battle)
                    Row(
                      children: [
                        // Exit Button
                        ElevatedButton(
                          onPressed: _isConnecting ? null : () => exit(0),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('EXIT',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),

                        // Offline Practice Button
                        Expanded(
                          flex: 1,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.smart_toy, size: 18),
                            label: const Text(
                              'PRACTICE (BOTS)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _isConnecting ? null : _playOfflinePractice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Online Join Button
                        Expanded(
                          flex: 1,
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connectAndPlay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 6,
                            ),
                            child: _isConnecting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.play_arrow, size: 20),
                                      SizedBox(width: 4),
                                      Text(
                                        'JOIN ONLINE',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
