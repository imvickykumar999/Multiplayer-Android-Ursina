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
  final TextEditingController _serverController = TextEditingController(text: 'game.24x7stream.shop');
  final TextEditingController _portController = TextEditingController(text: '8888');

  String _currentColorName = 'Blue';
  Color _currentColor = const Color.fromARGB(255, 52, 152, 219);
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final rnd = Random();
    _currentColorName = colorNames[rnd.nextInt(colorNames.length)];
    _currentColor = colorPalette[_currentColorName]!;
    _usernameController.text = _currentColorName;

    _usernameController.addListener(_onUsernameChanged);

    // Start background music loop matching Python client
    AudioService.playMusic();
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

  @override
  void dispose() {
    _usernameController.dispose();
    _serverController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connectAndPlay() async {
    final username = _usernameController.text.trim().isEmpty ? 'Player' : _usernameController.text.trim();
    final serverAddr = _serverController.text.trim().isEmpty ? 'game.24x7stream.shop' : _serverController.text.trim();
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
      final spawnPos = MapData.spawnPoints[rnd.nextInt(MapData.spawnPoints.length)];
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
        _errorMessage = 'Connection failed! Make sure server is reachable at $serverAddr:$port';
      });
    }
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
              errorBuilder: (_, _, _) => Container(color: const Color(0xFF010D25)),
            ),
          ),

          // Dark overlay for readable content
          Positioned.fill(
            child: Container(
              color: Colors.black.withAlpha(120),
            ),
          ),

          // Center Dialog Box matching Python Tkinter UI
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF010D25).withAlpha(240),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.lightBlue.withAlpha(100), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(180),
                      blurRadius: 20,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    const Text(
                      'Ursina TCP Deathmatch',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Username Label
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter your username:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Username Input + Dropdown quick-picks
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _usernameController,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withAlpha(20),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Colors.lightBlueAccent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.lightBlueAccent.withAlpha(120)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _currentColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.palette, color: Colors.white, size: 20),
                          ),
                          tooltip: 'Select Color',
                          color: const Color(0xFF0F2035),
                          onSelected: (colorName) {
                            _usernameController.text = colorName;
                          },
                          itemBuilder: (context) {
                            return colorNames.map((name) {
                              final col = colorPalette[name]!;
                              return PopupMenuItem(
                                value: name,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: col,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(name, style: const TextStyle(color: Colors.white)),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Color Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _currentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Player Color: $_currentColorName',
                          style: TextStyle(
                            color: _currentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Server Address Label
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter server address:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Server Address Input (Default: game.24x7stream.shop)
                    TextField(
                      controller: _serverController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withAlpha(20),
                        hintText: 'game.24x7stream.shop',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.lightBlueAccent),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.lightBlueAccent.withAlpha(120)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Port Label
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter port number:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Port Input (Default: 8888)
                    TextField(
                      controller: _portController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withAlpha(20),
                        hintText: '8888',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.lightBlueAccent),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.lightBlueAccent.withAlpha(120)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Error display if any
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action Buttons (Play / Close)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : () => exit(0),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connectAndPlay,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isConnecting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Play', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
