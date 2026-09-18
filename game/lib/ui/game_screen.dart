import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models/player.dart';
import '../models/enemy.dart';
import '../models/bullet.dart';
import '../models/map_data.dart';
import '../models/floating_damage.dart';
import '../services/network.dart';
import '../services/audio_service.dart';
import '../services/bot_manager.dart';
import '../rendering/renderer3d.dart';
import 'virtual_joystick.dart';
import 'minimap.dart';
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
  final List<ImpactSpark> _sparks = [];
  final List<FloatingDamage> _floatingDamages = [];
  late final List<ArenaBox> _arenaBoxes;
  BotManager? _botManager;

  double _inputMoveX = 0.0;
  double _inputMoveZ = 0.0;
  double _muzzleFlashTimer = 0.0;
  double _hitmarkerTimer = 0.0;
  bool _isHeadshotHit = false;
  double _damageVignetteTimer = 0.0;
  double _heartbeatTimer = 0.0;

  bool _isAds = false;
  double _currentFov = 75.0;

  String? _eliminationBanner;
  double _eliminationBannerTimer = 0.0;

  double _networkTimer = 0.0;
  vm.Vector3 _prevNetworkPos = vm.Vector3.zero();
  double _prevNetworkYaw = 0.0;

  // Touch & Gameplay Settings
  double _lookSensitivity = 0.25;
  bool _invertY = false;
  bool _showLeftFireButton = true;

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

    // Offline Bot Support
    if (widget.network.isOffline) {
      _botManager = BotManager(network: widget.network);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _botManager?.spawnInitialBots();
      });
    }

    // Ensure music stays playing smoothly
    AudioService.playMusic();

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
          if (hp < widget.player.health) {
            _damageVignetteTimer = 0.35;
            HapticFeedback.mediumImpact();
          }
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

  void _spawnImpactSparks(vm.Vector3 hitPos) {
    final rnd = Random();
    for (int i = 0; i < 7; i++) {
      final vx = (rnd.nextDouble() - 0.5) * 7.0;
      final vy = rnd.nextDouble() * 5.0 + 1.0;
      final vz = (rnd.nextDouble() - 0.5) * 7.0;
      _sparks.add(
        ImpactSpark(
          position: hitPos.clone(),
          velocity: vm.Vector3(vx, vy, vz),
          lifetime: 0.22 + rnd.nextDouble() * 0.18,
          color: rnd.nextBool()
              ? const Color(0xFFFFD54F)
              : const Color(0xFFFF7043),
        ),
      );
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
    widget.player.update(
      dt,
      _inputMoveX,
      _inputMoveZ,
      _arenaBoxes,
      enemies: _enemies,
    );

    // 1.5 Update Bot AI if in offline / practice mode
    _botManager?.update(
      dt,
      widget.player.position,
      widget.player.health <= 0,
      (eyePos, yaw, pitch, dmg) {
        final bullet = Bullet(
          startPos: eyePos,
          direction: yaw,
          xDirection: pitch,
          damage: dmg,
          slave: true,
        );
        setState(() {
          _bullets.add(bullet);
        });
        AudioService.playGunSound();
      },
    );

    // 2. Update Bullets & Hit Detection (with Wall Collisions & Floating Damage)
    _bullets.removeWhere((bullet) {
      return !bullet.update(
        dt,
        _enemies,
        (hitEnemy, dmg, isHeadshot) {
          setState(() {
            _hitmarkerTimer = 0.2;
            _isHeadshotHit = isHeadshot;
            HapticFeedback.lightImpact();

            // Spawn floating damage popup in 3D world space
            _floatingDamages.add(
              FloatingDamage(
                position: hitEnemy.position.clone() + vm.Vector3(0, 2.1, 0),
                text: isHeadshot ? '🎯 -$dmg CRIT' : '-$dmg',
                isHeadshot: isHeadshot,
              ),
            );

            hitEnemy.health = max(0, hitEnemy.health - dmg);
            if (hitEnemy.health <= 0) {
              hitEnemy.isDead = true;
              widget.player.recordKill();
              final streak = widget.player.killstreak;
              String streakText = '';
              if (streak == 2) streakText = ' 🔥 DOUBLE KILL!';
              if (streak == 3) streakText = ' ⚡ TRIPLE KILL!';
              if (streak == 5) streakText = ' 👑 KILLING SPREE!';
              if (streak >= 10) streakText = ' 💀 UNSTOPPABLE!';

              _eliminationBanner = isHeadshot
                  ? '🎯 HEADSHOT! ELIMINATED ${hitEnemy.username} (+150)$streakText'
                  : '⚔️ ELIMINATED ${hitEnemy.username} (+100)$streakText';
              _eliminationBannerTimer = 2.5;
            }
          });
          widget.network.sendHealth(hitEnemy.id, hitEnemy.health);
          _botManager?.onBotDamaged(hitEnemy.id, hitEnemy.health);
        },
        player: widget.player,
        onHitPlayer: (hitPlayer, dmg) {
          final updatedHealth = max(0, hitPlayer.health - dmg);
          setState(() {
            _damageVignetteTimer = 0.35;
            HapticFeedback.mediumImpact();

            _floatingDamages.add(
              FloatingDamage(
                position: hitPlayer.position.clone() + vm.Vector3(0, 1.8, 0),
                text: '-$dmg',
                isPlayerTakingDamage: true,
              ),
            );

            hitPlayer.health = updatedHealth;
            if (updatedHealth <= 0) {
              hitPlayer.death();
            }
          });
          widget.network.sendHealth(hitPlayer.id, updatedHealth);
        },
        arenaBoxes: _arenaBoxes,
        onHitObstacle: (pos) => _spawnImpactSparks(pos),
      );
    });

    // 3. Update Impact Sparks & Floating Damage Texts
    _sparks.removeWhere((spark) => !spark.update(dt));
    _floatingDamages.removeWhere((fd) => !fd.update(dt));

    // 3.5 Smooth FOV interpolation for ADS
    final targetFov = _isAds ? 45.0 : 75.0;
    _currentFov += (targetFov - _currentFov) * min(1.0, dt * 12.0);

    // 3.6 Low Health Heartbeat Pulse calculation
    if (widget.player.health <= 60 && widget.player.health > 0) {
      _heartbeatTimer += dt * 4.5;
    }

    // 4. Update Timers
    if (_muzzleFlashTimer > 0) {
      _muzzleFlashTimer = max(0.0, _muzzleFlashTimer - dt);
    }
    if (_hitmarkerTimer > 0) {
      _hitmarkerTimer = max(0.0, _hitmarkerTimer - dt);
    }
    if (_damageVignetteTimer > 0) {
      _damageVignetteTimer = max(0.0, _damageVignetteTimer - dt);
    }
    if (_eliminationBannerTimer > 0) {
      _eliminationBannerTimer -= dt;
      if (_eliminationBannerTimer <= 0) {
        _eliminationBanner = null;
      }
    }

    // 5. Send network updates at 30Hz (if online)
    if (!widget.network.isOffline) {
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
    HapticFeedback.selectionClick();

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
    widget.player.respawn(enemies: _enemies);
    widget.network.sendRespawn(widget.player.position, widget.player.health);
    widget.network.sendPlayer(
      widget.player.position,
      widget.player.yaw,
      widget.player.health,
    );
    setState(() {});
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF0C192E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text(
                'GAME SETTINGS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Look Sensitivity Slider
                Text(
                  'Look Sensitivity: ${(_lookSensitivity * 400).round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                Slider(
                  value: _lookSensitivity,
                  min: 0.05,
                  max: 0.60,
                  divisions: 11,
                  activeColor: Colors.cyanAccent,
                  onChanged: (val) {
                    setState(() => _lookSensitivity = val);
                    setModalState(() {});
                  },
                ),
                // Invert Pitch Toggle
                SwitchListTile(
                  title: const Text('Invert Vertical Aim (Pitch)',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: _invertY,
                  activeThumbColor: Colors.cyanAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() => _invertY = val);
                    setModalState(() {});
                  },
                ),
                // Left Fire Button Toggle
                SwitchListTile(
                  title: const Text('Show Left Fire Button',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  subtitle: const Text('Allows two-thumb aiming & shooting',
                      style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: _showLeftFireButton,
                  activeThumbColor: Colors.cyanAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() => _showLeftFireButton = val);
                    setModalState(() {});
                  },
                ),
                const Divider(color: Colors.white24),
                // Music Volume
                SwitchListTile(
                  title: const Text('Background Music',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  secondary: const Icon(Icons.music_note, color: Colors.cyanAccent, size: 20),
                  value: AudioService.isMusicEnabled,
                  activeThumbColor: Colors.cyanAccent,
                  contentPadding: EdgeInsets.zero,
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
                  onChanged: AudioService.isMusicEnabled
                      ? (val) {
                          AudioService.setMusicVolume(val);
                          setModalState(() {});
                        }
                      : null,
                ),
                // SFX Volume
                SwitchListTile(
                  title: const Text('Sound Effects (SFX)',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  secondary: const Icon(Icons.volume_up, color: Colors.lightBlueAccent, size: 20),
                  value: AudioService.isSfxEnabled,
                  activeThumbColor: Colors.lightBlueAccent,
                  contentPadding: EdgeInsets.zero,
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
                  onChanged: AudioService.isSfxEnabled
                      ? (val) {
                          AudioService.setSfxVolume(val);
                          setModalState(() {});
                        }
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.network.close();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LobbyScreen()),
                );
              },
              child: const Text('LEAVE GAME'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent[700],
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('RESUME'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isDead = player.health <= 0;
    final lowHealthPulse = (player.health <= 60 && !isDead)
        ? (sin(_heartbeatTimer).abs())
        : 0.0;

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
                fov: _currentFov,
                hitmarkerTimer: _hitmarkerTimer,
                isHeadshotHit: _isHeadshotHit,
                damageVignetteTimer: _damageVignetteTimer,
                sparks: _sparks,
                floatingDamages: _floatingDamages,
                isAds: _isAds,
                lowHealthPulse: lowHealthPulse,
              ),
            ),
          ),

          // Right half of the screen: Touch look pan area (excluding action button corner)
          Positioned(
            right: 0,
            top: 0,
            bottom: 120, // Leave space for bottom right buttons
            width: MediaQuery.of(context).size.width * 0.58,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (details) {
                if (isDead) return;
                final sensitivity = _isAds ? _lookSensitivity * 0.60 : _lookSensitivity;
                setState(() {
                  player.yaw += details.delta.dx * sensitivity;
                  final pitchDelta = details.delta.dy *
                      sensitivity *
                      (_invertY ? 1.0 : -1.0);
                  player.pitch =
                      (player.pitch + pitchDelta).clamp(-80.0, 80.0);
                });
              },
            ),
          ),

          // Top Left: Back & Pause/Settings buttons
          Positioned(
            left: 16,
            top: 16,
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 24),
                      tooltip: 'Leave Game',
                      onPressed: () {
                        widget.network.close();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LobbyScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings,
                          color: Colors.cyanAccent, size: 24),
                      tooltip: 'Settings',
                      onPressed: _showSettingsDialog,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Right: Tactical Minimap Radar & Arena Mode Badge
          if (!isDead)
            Positioned(
              right: 16,
              top: 16,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TacticalMinimap(
                      player: player,
                      enemies: _enemies,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.network.isOffline
                              ? Colors.amberAccent.withValues(alpha: 0.6)
                              : Colors.greenAccent.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.network.isOffline ? Icons.smart_toy : Icons.wifi,
                            color: widget.network.isOffline ? Colors.amberAccent : Colors.greenAccent,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.network.isOffline ? 'BOT ARENA' : 'ONLINE MATCH',
                            style: TextStyle(
                              color: widget.network.isOffline ? Colors.amberAccent : Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top Center: Modern Tactical HUD (Health, Ammo, K/D Scoreboard)
          if (!isDead)
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    // Glassmorphic Health & Ammo Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF081220).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (player.health <= 60)
                              ? Colors.redAccent.withValues(alpha: 0.7 + lowHealthPulse * 0.3)
                              : Colors.cyanAccent.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (player.health <= 60)
                                ? Colors.redAccent.withValues(alpha: 0.3 * lowHealthPulse)
                                : Colors.black.withValues(alpha: 0.6),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Health Section
                          Icon(
                            Icons.shield,
                            color: player.health <= 60 ? Colors.redAccent : Colors.greenAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 140,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.red[950],
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: Colors.white24, width: 1),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor:
                                        (player.health / 250.0).clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: player.health <= 60
                                              ? [const Color(0xFFFF1744), const Color(0xFFFF5252)]
                                              : [const Color(0xFF00E676), const Color(0xFF69F0AE)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${player.health} / 250 HP',
                                style: TextStyle(
                                  color: player.health <= 60 ? Colors.redAccent : Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Container(width: 1, height: 26, color: Colors.white24),
                          const SizedBox(width: 20),
                          // Ammo Section
                          const Icon(Icons.flash_on,
                              color: Colors.amberAccent, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            player.isReloading
                                ? 'RELOADING...'
                                : '${player.ammo} / ${player.magazineSize}',
                            style: TextStyle(
                              color: player.isReloading
                                  ? Colors.orangeAccent
                                  : (player.ammo <= 3
                                      ? Colors.redAccent
                                      : Colors.white),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Combat Stats Badge (Kills, Deaths, Streak)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        'KILLS: ${player.kills}   |   DEATHS: ${player.deaths}   |   STREAK: ${player.killstreak}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top Elimination Toast Banner
          if (_eliminationBanner != null)
            Positioned(
              top: 84,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE53935), Color(0xFFC62828)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.6),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    _eliminationBanner!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
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

          // Left Fire Button (Above Joystick for two-thumb combat)
          if (!isDead && _showLeftFireButton)
            Positioned(
              left: 56,
              bottom: 180,
              child: SafeArea(
                child: GestureDetector(
                  onTapDown: (_) => _shoot(),
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFE53935).withValues(alpha: 0.75),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.gps_fixed,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

          // ADS / Reflex Scope Toggle Button (Above Action Buttons)
          if (!isDead)
            Positioned(
              right: 36,
              bottom: 180,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAds = !_isAds;
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isAds
                          ? Colors.cyanAccent.withValues(alpha: 0.85)
                          : const Color(0xFF0C192E).withValues(alpha: 0.8),
                      border: Border.all(
                        color: _isAds ? Colors.white : Colors.cyanAccent.withValues(alpha: 0.5),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isAds
                              ? Colors.cyanAccent.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.center_focus_strong,
                      color: _isAds ? Colors.black87 : Colors.cyanAccent,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),

          // Bottom Right: Action Buttons (Reload, Jump, Main Shoot)
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
                          color: player.isReloading
                              ? Colors.grey.withValues(alpha: 0.7)
                              : Colors.orange.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
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
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2).withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
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

                        // Primary Shoot Button
                        GestureDetector(
                          onTapDown: (_) => _shoot(),
                          child: Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              gradient: const RadialGradient(
                                colors: [Color(0xFFFF5252), Color(0xFFC62828)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.6),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.gps_fixed,
                              color: Colors.white,
                              size: 42,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Death & Respawn Overlay
          if (isDead)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/background.jpg'),
                    fit: BoxFit.cover,
                  ),
                  color: Colors.black.withValues(alpha: 0.8),
                ),
                child: Container(
                  color: const Color(0xFF000511).withValues(alpha: 0.75),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dangerous,
                            color: Colors.redAccent, size: 64),
                        const SizedBox(height: 8),
                        const Text(
                          'YOU WERE ELIMINATED',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 12,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'KILLS THIS ROUND: ${player.kills}   |   HIGHEST STREAK: ${player.highestStreak}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Auto-respawn in ${max(1, player.respawnTimer.ceil())}s...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.replay, size: 22),
                          label: const Text(
                            'RESPAWN NOW',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          onPressed: _respawn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
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
