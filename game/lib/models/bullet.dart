import 'dart:math';

import 'package:vector_math/vector_math_64.dart';

import 'enemy.dart';
import 'map_data.dart';
import 'player.dart';

class Bullet {
  Vector3 position;
  final Vector3 velocity;
  final double direction; // yaw in degrees
  final double xDirection; // pitch in degrees
  final int damage;
  final bool slave;
  double lifetime = 2.0;
  bool isDestroyed = false;

  Bullet({
    required Vector3 startPos,
    required this.direction,
    required this.xDirection,
    required this.damage,
    this.slave = false,
  }) : velocity = Vector3.zero(),
       position = startPos.clone() {
    const double speed = 40.0;
    final dirRad = direction * pi / 180.0;
    final xDirRad = xDirection * pi / 180.0;

    velocity.x = sin(dirRad) * cos(xDirRad) * speed;
    velocity.y = sin(xDirRad) * speed;
    velocity.z = cos(dirRad) * cos(xDirRad) * speed;

    final norm = velocity.normalized();
    position += norm * 0.8;
  }

  bool update(
    double dt,
    List<Enemy> enemies,
    Function(Enemy enemy, int damage, bool isHeadshot) onHitEnemy, {
    Player? player,
    Function(Player player, int damage)? onHitPlayer,
    List<ArenaBox>? arenaBoxes,
    Function(Vector3 impactPoint)? onHitObstacle,
  }) {
    if (isDestroyed) return false;

    lifetime -= dt;
    if (lifetime <= 0) {
      isDestroyed = true;
      return false;
    }

    final prevPos = position.clone();
    position += velocity * dt;

    // 1. Continuous Swept Collision against walls, pillars, barricades, and floors to prevent tunneling
    if (arenaBoxes != null) {
      final minTravelX = min(prevPos.x, position.x);
      final maxTravelX = max(prevPos.x, position.x);
      final minTravelY = min(prevPos.y, position.y);
      final maxTravelY = max(prevPos.y, position.y);
      final minTravelZ = min(prevPos.z, position.z);
      final maxTravelZ = max(prevPos.z, position.z);

      for (final box in arenaBoxes) {
        // Allow bullets to travel over ground floor
        if (box.textureType == 'floor' &&
            box.center.y <= 0.5 &&
            prevPos.y > 1.0 &&
            position.y > 1.0) {
          continue;
        }

        const margin = 0.2;
        final boxMinX = box.minX - margin;
        final boxMaxX = box.maxX + margin;
        final boxMinY = box.minY - margin;
        final boxMaxY = box.maxY + margin;
        final boxMinZ = box.minZ - margin;
        final boxMaxZ = box.maxZ + margin;

        if (maxTravelX >= boxMinX &&
            minTravelX <= boxMaxX &&
            maxTravelY >= boxMinY &&
            minTravelY <= boxMaxY &&
            maxTravelZ >= boxMinZ &&
            minTravelZ <= boxMaxZ) {
          isDestroyed = true;
          onHitObstacle?.call(prevPos);
          return false;
        }
      }
    }

    // 2. Collision against local player (if bullet is from remote enemy)
    if (slave && player != null && onHitPlayer != null && player.health > 0) {
      final dx = (position.x - player.position.x).abs();
      final dz = (position.z - player.position.z).abs();
      final dy = position.y - player.position.y;

      if (dx < 0.9 && dz < 0.9 && dy >= -0.2 && dy <= 2.2) {
        isDestroyed = true;
        onHitPlayer(player, damage);
        onHitObstacle?.call(position.clone());
        return false;
      }
    }

    // 3. Collision against remote enemies (if bullet is from local player)
    if (!slave) {
      for (final enemy in enemies) {
        if (!enemy.isDead && enemy.health > 0) {
          final dx = (position.x - enemy.position.x).abs();
          final dz = (position.z - enemy.position.z).abs();
          final dy = position.y - enemy.position.y;

          if (dx < 0.9 && dz < 0.9 && dy >= -0.2 && dy <= 2.2) {
            isDestroyed = true;
            // Head section is near top of 1.8m body model
            final isHeadshot = dy >= 1.35;
            final dealtDamage = isHeadshot ? (damage * 1.5).round() : damage;
            onHitEnemy(enemy, dealtDamage, isHeadshot);
            onHitObstacle?.call(position.clone());
            return false;
          }
        }
      }
    }

    return true;
  }
}
