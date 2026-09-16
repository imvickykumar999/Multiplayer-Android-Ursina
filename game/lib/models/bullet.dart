import 'dart:math';
import 'package:vector_math/vector_math_64.dart';
import 'enemy.dart';

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
  })  : velocity = Vector3.zero(),
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

  bool update(double dt, List<Enemy> enemies, Function(Enemy enemy, int damage) onHitEnemy) {
    if (isDestroyed) return false;

    lifetime -= dt;
    if (lifetime <= 0) {
      isDestroyed = true;
      return false;
    }

    position += velocity * dt;

    // Check hit against remote enemies if this is our local bullet
    if (!slave) {
      for (final enemy in enemies) {
        if (!enemy.isDead && enemy.health > 0) {
          // Enemy collider is roughly 1.0 x 2.0 x 1.0 box centered at (x, y + 1.0, z)
          final dx = (position.x - enemy.position.x).abs();
          final dz = (position.z - enemy.position.z).abs();
          final dy = position.y - enemy.position.y;

          if (dx < 0.9 && dz < 0.9 && dy >= -0.2 && dy <= 2.2) {
            isDestroyed = true;
            onHitEnemy(enemy, damage);
            return false;
          }
        }
      }
    }

    return true;
  }
}
