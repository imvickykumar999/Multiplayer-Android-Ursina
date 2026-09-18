import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

import 'enemy.dart';
import 'map_data.dart';

class Player {
  Vector3 position;
  double yaw; // In degrees, looking along +Z when 0
  double pitch; // In degrees, clamped between -80 and 80
  int health;
  final int maxHealth;
  int ammo;
  final int magazineSize;
  bool isReloading = false;
  double reloadTimer = 0.0;
  final double reloadTime = 2.0;

  double velocityY = 0.0;
  bool isGrounded = true;
  double speed = 7.0;

  bool deathMessageShown = false;
  double respawnTimer = 0.0;

  // Combat Stats
  int kills = 0;
  int deaths = 0;
  int killstreak = 0;
  int highestStreak = 0;

  final String id;
  final String username;
  final Color color;

  Player({
    required Vector3 startPos,
    required this.id,
    required this.username,
    Color? color,
  }) : position = startPos.clone(),
       yaw = 0.0,
       pitch = 0.0,
       maxHealth = 250,
       health = 250,
       magazineSize = 15,
       ammo = 15,
       color = color ?? getPlayerColor(id, username);

  void jump() {
    if (isGrounded && health > 0) {
      velocityY = 10.0;
      isGrounded = false;
    }
  }

  void reload() {
    if (health <= 0 || isReloading || ammo >= magazineSize) return;
    isReloading = true;
    reloadTimer = reloadTime;
  }

  void recordKill() {
    kills++;
    killstreak++;
    if (killstreak > highestStreak) {
      highestStreak = killstreak;
    }
  }

  void recordDeath() {
    deaths++;
    killstreak = 0;
  }

  void death() {
    if (deathMessageShown) return;
    deathMessageShown = true;
    health = 0;
    respawnTimer = 5.0;
    recordDeath();
  }

  void respawn({Vector3? chosenPos, List<Enemy>? enemies}) {
    Vector3 pos;
    if (chosenPos != null) {
      pos = chosenPos;
    } else if (enemies != null && enemies.isNotEmpty) {
      // Pick spawn point furthest away from living enemies to prevent instant spawn camp
      final activeEnemies = enemies.where((e) => !e.isDead && e.health > 0).toList();
      if (activeEnemies.isNotEmpty) {
        Vector3 bestPoint = MapData.spawnPoints.first;
        double maxMinDist = -1;
        for (final sp in MapData.spawnPoints) {
          double minDistToEnemy = double.infinity;
          for (final enemy in activeEnemies) {
            final dist = (sp - enemy.position).length;
            if (dist < minDistToEnemy) minDistToEnemy = dist;
          }
          if (minDistToEnemy > maxMinDist) {
            maxMinDist = minDistToEnemy;
            bestPoint = sp;
          }
        }
        pos = bestPoint;
      } else {
        final rnd = Random();
        pos = MapData.spawnPoints[rnd.nextInt(MapData.spawnPoints.length)];
      }
    } else {
      final rnd = Random();
      pos = MapData.spawnPoints[rnd.nextInt(MapData.spawnPoints.length)];
    }

    position = pos.clone();
    health = maxHealth;
    ammo = magazineSize;
    isReloading = false;
    reloadTimer = 0.0;
    deathMessageShown = false;
    respawnTimer = 0.0;
    velocityY = 0.0;
    yaw = 0.0;
    pitch = 0.0;
  }

  void update(
    double dt,
    double inputX,
    double inputZ,
    List<ArenaBox> arenaBoxes, {
    List<Enemy>? enemies,
  }) {
    if (health <= 0) {
      if (!deathMessageShown) {
        death();
      } else {
        respawnTimer -= dt;
        if (respawnTimer <= 0) {
          respawn(enemies: enemies);
        }
      }
      return;
    }

    // Handle reloading
    if (ammo <= 0 && !isReloading) {
      reload();
    }
    if (isReloading) {
      reloadTimer -= dt;
      if (reloadTimer <= 0) {
        ammo = magazineSize;
        isReloading = false;
        reloadTimer = 0.0;
      }
    }

    // Apply movement
    if (inputX != 0 || inputZ != 0) {
      final yawRad = yaw * pi / 180.0;
      final forward = Vector3(sin(yawRad), 0, cos(yawRad));
      final right = Vector3(cos(yawRad), 0, -sin(yawRad));

      final moveDir = (forward * inputZ + right * inputX);
      if (moveDir.length > 0.001) {
        moveDir.normalize();
        final deltaPos = moveDir * (speed * dt);
        position.x += deltaPos.x;
        position.z += deltaPos.z;
      }
    }

    // Gravity & Vertical Physics
    const gravity = 25.0;
    velocityY -= gravity * dt;
    position.y += velocityY * dt;

    // Check floor height at current (x, z)
    final floorY = _calculateFloorHeight(position.x, position.z, position.y);

    if (position.y <= floorY) {
      position.y = floorY;
      velocityY = 0.0;
      isGrounded = true;
    } else {
      isGrounded = false;
    }

    // Ceiling collision check: if on ground floor jumping under an upper slab (height 5.5 to 6.0)
    if (position.y < 5.5 && position.y + 1.8 >= 5.5 && velocityY > 0) {
      final x = position.x;
      final z = position.z;
      final underUpperPlatform =
          (x >= -20 && x <= 20 && z >= 6 && z <= 20) ||
          (x >= -20 && x <= 20 && z >= -20 && z <= -6) ||
          (x >= 12 && x <= 20 && z >= -6 && z <= 6) ||
          (x >= -20 && x <= -12 && z >= -6 && z <= 6);
      if (underUpperPlatform) {
        position.y = 5.5 - 1.8;
        velocityY = 0.0;
      }
    }

    // Out of bounds check
    if (position.y < -20.0) {
      death();
      return;
    }

    // Wall collision resolution (sliding along walls)
    _resolveWallCollisions(arenaBoxes);
  }

  double _calculateFloorHeight(double x, double z, double currentY) {
    // Upper platforms are not ramps. Only use them when the player is already
    // at that elevation; the stair strips below provide the only ground-level
    // route onto the first floor.
    final canStandOnUpperFloor = currentY >= 5.4;

    // 1st Floor Slabs (height Y = 6.0)
    // North platform: X: [-20, 20], Z: [6, 20]
    if (canStandOnUpperFloor && x >= -20 && x <= 20 && z >= 6 && z <= 20) {
      return 6.0;
    }
    // South platform: X: [-20, 20], Z: [-20, -6]
    if (canStandOnUpperFloor && x >= -20 && x <= 20 && z >= -20 && z <= -6) {
      return 6.0;
    }
    // East walkway: X: [12, 20], Z: [-6, 6]
    if (canStandOnUpperFloor && x >= 12 && x <= 20 && z >= -6 && z <= 6) {
      return 6.0;
    }
    // West walkway: X: [-20, -12], Z: [-6, 6]
    if (canStandOnUpperFloor && x >= -20 && x <= -12 && z >= -6 && z <= 6) {
      return 6.0;
    }

    // East Stair: X: [6.75, 10.25], Z: [-4, 6] -> slope from Y = 1.0 (at Z = -4) to Y = 6.0 (at Z = 6)
    if (x >= 6.75 && x <= 10.25 && z >= -4.0 && z <= 6.0) {
      final t = (z - (-4.0)) / (6.0 - (-4.0));
      return 1.0 + t * 5.0;
    }

    // West Stair: X: [-10.25, -6.75], Z: [-6, 4] -> slope from Y = 1.0 (at Z = 4) to Y = 6.0 (at Z = -6)
    if (x >= -10.25 && x <= -6.75 && z >= -6.0 && z <= 4.0) {
      final t = (4.0 - z) / (4.0 - (-6.0));
      return 1.0 + t * 5.0;
    }

    // Ground floor footprint: X: [-20, 20], Z: [-20, 20] -> height Y = 1.0
    if (x >= -20 && x <= 20 && z >= -20 && z <= 20) {
      return 1.0;
    }

    // Falling off edge
    return -999.0;
  }

  void _resolveWallCollisions(List<ArenaBox> arenaBoxes) {
    const playerRadius = 0.45;
    for (final box in arenaBoxes) {
      // Only collide with walls, pillars, barricades, and railings
      if (box.textureType == 'floor' || box.textureType == 'stair') continue;

      // Check vertical overlap (player height roughly Y to Y + 1.8)
      if (position.y + 1.8 < box.minY || position.y > box.maxY) continue;

      final minX = box.minX - playerRadius;
      final maxX = box.maxX + playerRadius;
      final minZ = box.minZ - playerRadius;
      final maxZ = box.maxZ + playerRadius;

      if (position.x > minX &&
          position.x < maxX &&
          position.z > minZ &&
          position.z < maxZ) {
        // Penetration distances
        final dLeft = position.x - minX;
        final dRight = maxX - position.x;
        final dFront = position.z - minZ;
        final dBack = maxZ - position.z;

        final minOverlap = [dLeft, dRight, dFront, dBack].reduce(min);

        if (minOverlap == dLeft) {
          position.x = minX;
        } else if (minOverlap == dRight) {
          position.x = maxX;
        } else if (minOverlap == dFront) {
          position.z = minZ;
        } else {
          position.z = maxZ;
        }
      }
    }
  }
}
