import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models/player.dart';
import '../models/enemy.dart';
import '../models/bullet.dart';
import '../models/map_data.dart';
import '../services/network.dart';
import '../services/audio_service.dart';
import '../rendering/renderer3d.dart';
import 'virtual_joystick.dart';
import 'lobby_screen.dart';

class GameScreen extends StatefulWidget {
  final NetworkService network;
  final Player player;

  const GameScreen({super.key, required this.network, required this.player});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _lastDuration = Duration.zero;

  final List<Enemy> _enemies = [];
  final List<Bullet> _bullets = [];
  late final List<ArenaBox> _arenaBoxes;

  double _inputMoveX = 0.0;
  double _inputMoveZ = 0.0;
  double _muzzleFlashTimer = 0.0;

  double _networkTimer = 0.0;
  vm.Vector3 _prevNetworkPos = vm.Vector3.zero();
  double _prevNetworkYaw = 0.0;

  @override
  void initState() {
    super.initState();
    _arenaBoxes = MapData.getArenaBoxes();
    _prevNetworkPos = widget.player.position.clone();
    _prevNetworkYaw = widget.player.yaw;

    // Listen for server packets
    widget.network.addListener(_handleServerMessage);

    // Initial player broadcast
    widget.network.sendPlayer(
      widget.player.position,
      widget.player.yaw,
      widget.player.health,
    );

    // 60 FPS Game Loop Ticker
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.network.removeListener(_handleServerMessage);
    widget.network.close();
    super.dispose();
  }

  void _handleServerMessage(Map<String, dynamic> msg) {
    if (!mounted) return;

    final obj = msg["object"];
    if (obj == "player") {
      final enemyId = msg["id"]?.toString();
      if (enemyId == null || enemyId == widget.player.id) return;

      if (msg["left"] == true) {
        setState(() {
          _enemies.removeWhere((e) => e.id == enemyId);
        });
        return;
      }

      Enemy? existing;
      for (final e in _enemies) {
        if (e.id == enemyId) {
          existing = e;
          break;
        }
      }

      final posList = msg["position"] as List?;
      final pos = posList != null
          ? vm.Vector3(
              (posList[0] as num).toDouble(),
              (posList[1] as num).toDouble(),
              (posList[2] as num).toDouble(),
            )
          : vm.Vector3(0, 1, 0);
      final rot = (msg["rotation"] as num?)?.toDouble() ?? 0.0;
      final hp = (msg["health"] as num?)?.toInt() ?? 250;
      final username = msg["username"]?.toString() ?? 'Player $enemyId';

      setState(() {
        if (existing == null) {
          final newEnemy = Enemy(
            id: enemyId,
            username: username,
            position: pos,
            rotationY: rot,
            health: hp,
          );
          _enemies.add(newEnemy);
        } else {
          existing.position = pos;
          existing.rotationY = rot;
          if (existing.health <= 0 && hp > 0) {
            existing.respawn(pos, hp);
          } else {
            existing.health = hp;
            existing.isDead = hp <= 0;
          }
        }
      });
    } else if (obj == "player_respawn" || obj == "respawn") {
      final enemyId = msg["id"]?.toString();
      if (enemyId == null || enemyId == widget.player.id) return;

      final posList = msg["position"] as List?;
      final pos = posList != null
          ? vm.Vector3(
              (posList[0] as num).toDouble(),
              (posList[1] as num).toDouble(),
              (posList[2] as num).toDouble(),
            )
          : vm.Vector3(0, 1, 0);
      final hp = (msg["health"] as num?)?.toInt() ?? 250;

      setState(() {
        for (final e in _enemies) {
          if (e.id == enemyId) {
            e.respawn(pos, hp);
            break;
          }
        }
      });
    } else if (obj == "bullet") {
      final posList = msg["position"] as List?;
      if (posList == null) return;
      final pos = vm.Vector3(
        (posList[0] as num).toDouble(),
        (posList[1] as num).toDouble(),
        (posList[2] as num).toDouble(),
      );
      final dir = (msg["direction"] as num).toDouble();
      final xDir = (msg["x_direction"] as num).toDouble();
      final damage = (msg["damage"] as num?)?.toInt() ?? 15;

      final bullet = Bullet(
        startPos: pos,
        direction: dir,
        xDirection: xDir,
        damage: damage,
        slave: true,
      );
      setState(() {
        _bullets.add(bullet);
      });
      AudioService.playGunSound();
    } else if (obj == "health_update") {
      final targetId = msg["id"]?.toString();
      final hp = (msg["health"] as num?)?.toInt() ?? 250;
      setState(() {
        if (targetId == widget.player.id) {
          widget.player.health = hp;
          if (hp <= 0) {
            widget.player.death();
          }
        } else {
          for (final e in _enemies) {
            if (e.id == targetId) {
              e.health = hp;
              e.isDead = hp <= 0;
              break;
            }
          }
        }
      });
    }
  }

  void _onTick(Duration duration) {
    if (_lastDuration == Duration.zero) {
      _lastDuration = duration;
      return;
    }

    final dt = (duration - _lastDuration).inMicroseconds / 1000000.0;
    _lastDuration = duration;

    if (dt <= 0 || dt > 0.1) return; // Ignore lag spikes

    // 1. Update Player Physics
    widget.player.update(dt, _inputMoveX, _inputMoveZ, _arenaBoxes);

    // 2. Update Bullets & Hit Detection
    _bullets.removeWhere((bullet) {
      return !bullet.update(
        dt,
        _enemies,
        (hitEnemy, dmg) {
          setState(() {
            hitEnemy.health = max(0, hitEnemy.health - dmg);
            if (hitEnemy.health <= 0) {
              hitEnemy.isDead = true;
            }
          });
          widget.network.sendHealth(hitEnemy.id, hitEnemy.health);
        },
        player: widget.player,
        onHitPlayer: (hitPlayer, dmg) {
          final updatedHealth = max(0, hitPlayer.health - dmg);
          setState(() {
            hitPlayer.health = updatedHealth;
            if (updatedHealth <= 0) {
              hitPlayer.death();
            }
          });
          widget.network.sendHealth(hitPlayer.id, updatedHealth);
        },
      );
    });

    // 3. Update Muzzle Flash
    if (_muzzleFlashTimer > 0) {
      _muzzleFlashTimer -= dt;
      if (_muzzleFlashTimer < 0) _muzzleFlashTimer = 0.0;
    }

    // 4. Send network updates at 30Hz
    _networkTimer += dt;
    if (_networkTimer >= 0.033) {
      _networkTimer = 0.0;
      final posDiff = (widget.player.position - _prevNetworkPos).length;
      final rotDiff = (widget.player.yaw - _prevNetworkYaw).abs();
      if (posDiff > 0.01 || rotDiff > 0.5) {
        widget.network.sendPlayer(
          widget.player.position,
          widget.player.yaw,
          widget.player.health,
        );
        _prevNetworkPos = widget.player.position.clone();
        _prevNetworkYaw = widget.player.yaw;
      }
    }

    setState(() {});
  }

  void _shoot() {
    final player = widget.player;
    if (player.health <= 0 || player.isReloading) return;

    if (player.ammo <= 0) {
      player.reload();
      return;
    }

    player.ammo--;
    _muzzleFlashTimer = 0.08;

    final eyePos = vm.Vector3(
      player.position.x,
      player.position.y + 1.4,
      player.position.z,
    );
    final rnd = Random();
    final damage = rnd.nextInt(15) + 10; // 10 to 25

    final bullet = Bullet(
      startPos: eyePos,
      direction: player.yaw,
      xDirection: player.pitch,
      damage: damage,
      slave: false,
    );

    _bullets.add(bullet);
    widget.network.sendBullet(eyePos, damage, player.yaw, player.pitch);
    AudioService.playGunSound();

    if (player.ammo <= 0) {
      player.reload();
    }
  }

  void _respawn() {
    widget.player.respawn();
    widget.network.sendRespawn(widget.player.position, widget.player.health);
    widget.network.sendPlayer(
      widget.player.position,
      widget.player.yaw,
      widget.player.health,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isDead = player.health <= 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 3D Canvas Viewport
          Positioned.fill(
            child: CustomPaint(
              painter: ArenaRenderer3D(
                player: player,
                enemies: _enemies,
                bullets: _bullets,
                arenaBoxes: _arenaBoxes,
                muzzleFlashTimer: _muzzleFlashTimer,
              ),
            ),
          ),

          // Right half of the screen: Touch look pan area
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.55,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                if (isDead) return;
                setState(() {
                  player.yaw += details.delta.dx * 0.25;
                  player.pitch = (player.pitch - details.delta.dy * 0.25).clamp(
                    -80.0,
                    80.0,
                  );
                });
              },
            ),
          ),

          // Top Left: Back to Lobby button
          Positioned(
            left: 16,
            top: 16,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  widget.network.close();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LobbyScreen()),
                  );
                },
              ),
            ),
          ),

          // Top Center: Health Bar & Ammo Status HUD
          if (!isDead)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    // Health Bar Container (width 260, height 18)
                    Container(
                      width: 260,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.red[900],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(120),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (player.health / 250.0).clamp(0.0, 1.0),
                          child: Container(color: Colors.greenAccent[400]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Health text
                    Text(
                      '${player.health} / ${player.maxHealth} HP',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Ammo text
                    Text(
                      '${player.ammo} / ${player.magazineSize}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),

                    // Reloading status indicator
                    if (player.isReloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Reloading... ${max(0.0, player.reloadTimer).toStringAsFixed(1)}s',
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Bottom Left: Virtual Movement Joystick
          if (!isDead)
            Positioned(
              left: 36,
              bottom: 36,
              child: SafeArea(
                child: VirtualJoystick(
                  radius: 65,
                  stickRadius: 28,
                  onChange: (x, y) {
                    setState(() {
                      _inputMoveX = x;
                      _inputMoveZ = y;
                    });
                  },
                ),
              ),
            ),

          // Bottom Right: Action Buttons (Fire, Jump, Reload)
          if (!isDead)
            Positioned(
              right: 28,
              bottom: 28,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reload Button
                    GestureDetector(
                      onTap: player.reload,
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(190),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(120),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Jump & Shoot Row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Jump Button
                        GestureDetector(
                          onTap: player.jump,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(190),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(120),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_upward,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),

                        // Shoot Button (Primary Action)
                        GestureDetector(
                          onTapDown: (_) => _shoot(),
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              gradient: const RadialGradient(
                                colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withAlpha(150),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.gps_fixed,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Death Screen Overlay matching Python client
          if (isDead)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/background.jpg'),
                    fit: BoxFit.cover,
                  ),
                  color: Colors.black.withAlpha(200),
                ),
                child: Container(
                  color: Colors.black.withAlpha(150),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'YOU DIED',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.0,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 10,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tap RESPAWN to re-enter combat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Auto-respawn in ${max(1, player.respawnTimer.ceil())}s...',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: _respawn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 8,
                          ),
                          child: const Text(
                            'RESPAWN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
