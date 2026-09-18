import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../models/enemy.dart';
import '../models/map_data.dart';
import 'network.dart';

class BotEntity {
  final String id;
  final String name;
  final Color color;
  vm.Vector3 position;
  double yaw = 0.0;
  double pitch = 0.0;
  int health = 250;
  bool isDead = false;
  double respawnTimer = 0.0;
  double shootCooldown = 1.5;
  double moveTimer = 0.0;
  double strafeDir = 1.0;

  BotEntity({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
  });

  void respawn(vm.Vector3 newPos) {
    position = newPos.clone();
    health = 250;
    isDead = false;
    respawnTimer = 0.0;
    shootCooldown = 1.0 + Random().nextDouble();
    yaw = Random().nextDouble() * 360;
    pitch = 0.0;
  }
}

class BotManager {
  final NetworkService network;
  final List<BotEntity> bots = [];
  final Random _rnd = Random();
  double _broadcastTimer = 0.0;

  BotManager({required this.network}) {
    _initBots();
  }

  void _initBots() {
    final botProfiles = [
      {'name': 'Bot Alpha', 'color': const Color(0xFFE74C3C)},
      {'name': 'Bot Bravo', 'color': const Color(0xFF2ECC71)},
      {'name': 'Bot Charlie', 'color': const Color(0xFF9B59B6)},
      {'name': 'Bot Delta', 'color': const Color(0xFFE67E22)},
    ];

    final spawns = MapData.spawnPoints;
    for (int i = 0; i < botProfiles.length; i++) {
      final id = 'bot_${i + 100}';
      final profile = botProfiles[i];
      final pos = spawns[(i + 1) % spawns.length].clone();
      final bot = BotEntity(
        id: id,
        name: profile['name'] as String,
        color: profile['color'] as Color,
        position: pos,
      );
      bots.add(bot);
    }
  }

  /// Broadcast initial bot presence so the game screen registers them
  void spawnInitialBots() {
    for (final bot in bots) {
      network.dispatchServerMessage({
        'object': 'player',
        'id': bot.id,
        'username': bot.name,
        'position': [bot.position.x, bot.position.y, bot.position.z],
        'rotation': bot.yaw,
        'health': bot.health,
      });
    }
  }

  void update(
    double dt,
    vm.Vector3 playerPos,
    bool playerIsDead,
    Function(vm.Vector3 eyePos, double yaw, double pitch, int dmg) onBotShoot,
  ) {
    _broadcastTimer += dt;
    final shouldBroadcast = _broadcastTimer >= 0.05; // 20Hz update
    if (shouldBroadcast) {
      _broadcastTimer = 0.0;
    }

    for (final bot in bots) {
      if (bot.isDead) {
        bot.respawnTimer -= dt;
        if (bot.respawnTimer <= 0) {
          final spawns = MapData.spawnPoints;
          final newPos = spawns[_rnd.nextInt(spawns.length)].clone();
          bot.respawn(newPos);
          network.dispatchServerMessage({
            'object': 'respawn',
            'id': bot.id,
            'position': [bot.position.x, bot.position.y, bot.position.z],
            'health': bot.health,
          });
        }
        continue;
      }

      // Check if bot was killed
      if (bot.health <= 0) {
        bot.isDead = true;
        bot.respawnTimer = 4.0;
        continue;
      }

      // AI Logic: Aim and track player
      final toPlayer = playerPos - bot.position;
      final dist = toPlayer.length;

      // Calculate yaw & pitch to look at player
      if (dist > 0.1) {
        final targetYaw = atan2(toPlayer.x, toPlayer.z) * 180.0 / pi;
        final targetPitch = atan2(toPlayer.y + 0.5, sqrt(toPlayer.x * toPlayer.x + toPlayer.z * toPlayer.z)) * 180.0 / pi;

        // Smooth angle interpolation
        var yawDiff = (targetYaw - bot.yaw) % 360;
        if (yawDiff > 180) yawDiff -= 360;
        if (yawDiff < -180) yawDiff += 360;
        bot.yaw += yawDiff * min(1.0, dt * 5.0);
        bot.pitch = targetPitch.clamp(-60.0, 60.0);
      }

      // Movement behavior
      bot.moveTimer -= dt;
      if (bot.moveTimer <= 0) {
        bot.moveTimer = 1.5 + _rnd.nextDouble() * 2.0;
        bot.strafeDir = _rnd.nextBool() ? 1.0 : -1.0;
      }

      const botSpeed = 4.2;
      final radYaw = bot.yaw * pi / 180.0;
      final fwd = vm.Vector3(sin(radYaw), 0, cos(radYaw));
      final right = vm.Vector3(cos(radYaw), 0, -sin(radYaw));

      vm.Vector3 moveDir = vm.Vector3.zero();
      if (dist > 14.0) {
        // Approach player
        moveDir = fwd;
      } else if (dist < 5.0) {
        // Back up
        moveDir = fwd * -0.8 + right * (bot.strafeDir * 0.6);
      } else {
        // Tactical strafe
        moveDir = right * bot.strafeDir;
      }

      if (moveDir.length > 0.01) {
        moveDir.normalize();
        final nextPos = bot.position + moveDir * (botSpeed * dt);
        // Keep within arena bounds
        bot.position.x = nextPos.x.clamp(-18.0, 18.0);
        bot.position.z = nextPos.z.clamp(-18.0, 18.0);
      }

      // Shooting logic
      if (!playerIsDead && dist < 24.0) {
        bot.shootCooldown -= dt;
        if (bot.shootCooldown <= 0) {
          bot.shootCooldown = 1.2 + _rnd.nextDouble() * 1.0; // Cooldown 1.2s - 2.2s

          // Add slight inaccuracy/spread
          final spreadYaw = bot.yaw + (_rnd.nextDouble() - 0.5) * 8.0;
          final spreadPitch = bot.pitch + (_rnd.nextDouble() - 0.5) * 6.0;
          final eyePos = vm.Vector3(bot.position.x, bot.position.y + 1.2, bot.position.z);
          final dmg = 12 + _rnd.nextInt(10); // 12-21 damage

          onBotShoot(eyePos, spreadYaw, spreadPitch, dmg);
        }
      }

      // Broadcast position
      if (shouldBroadcast) {
        network.dispatchServerMessage({
          'object': 'player',
          'id': bot.id,
          'username': bot.name,
          'position': [bot.position.x, bot.position.y, bot.position.z],
          'rotation': bot.yaw,
          'health': bot.health,
        });
      }
    }
  }

  void onBotDamaged(String botId, int newHealth) {
    for (final bot in bots) {
      if (bot.id == botId) {
        bot.health = newHealth;
        if (newHealth <= 0) {
          bot.isDead = true;
          bot.respawnTimer = 4.0;
        }
        break;
      }
    }
  }
}
