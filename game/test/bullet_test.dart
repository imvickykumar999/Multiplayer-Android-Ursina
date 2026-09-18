import 'package:flutter_test/flutter_test.dart';
import 'package:game/models/bullet.dart';
import 'package:game/models/enemy.dart';
import 'package:game/models/map_data.dart';
import 'package:game/models/player.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('remote bullet damages the local player', () {
    final player = Player(
      startPos: Vector3(0, 1, 0),
      id: '1',
      username: 'Blue',
    );
    final bullet = Bullet(
      startPos: Vector3(0, 2, -0.8),
      direction: 0,
      xDirection: 0,
      damage: 25,
      slave: true,
    );
    var reportedDamage = 0;

    final alive = bullet.update(
      0.01,
      [],
      (_, _, _) {},
      player: player,
      onHitPlayer: (_, damage) => reportedDamage = damage,
    );

    expect(alive, isFalse);
    expect(reportedDamage, 25);
    expect(bullet.isDestroyed, isTrue);
  });

  test('local bullet deals headshot damage to remote enemy', () {
    final enemy = Enemy(
      id: '2',
      username: 'Red',
      position: Vector3(0, 1, 10),
      health: 250,
    );
    // Aim at head height (dy >= 1.35)
    final bullet = Bullet(
      startPos: Vector3(0, 2.5, 9.2),
      direction: 0,
      xDirection: 0,
      damage: 20,
      slave: false,
    );

    int reportedDamage = 0;
    bool headshotFlag = false;

    final alive = bullet.update(
      0.01,
      [enemy],
      (_, damage, isHeadshot) {
        reportedDamage = damage;
        headshotFlag = isHeadshot;
      },
    );

    expect(alive, isFalse);
    expect(headshotFlag, isTrue);
    expect(reportedDamage, (20 * 1.5).round());
  });

  test('bullet stops upon colliding with arena wall', () {
    final wall = ArenaBox(
      center: Vector3(0, 2, 5),
      scale: Vector3(4, 4, 1),
      textureType: 'wall',
    );
    final bullet = Bullet(
      startPos: Vector3(0, 2, 4.2),
      direction: 0,
      xDirection: 0,
      damage: 20,
      slave: false,
    );

    bool hitObstacle = false;
    final alive = bullet.update(
      0.05,
      [],
      (_, _, _) {},
      arenaBoxes: [wall],
      onHitObstacle: (_) => hitObstacle = true,
    );

    expect(alive, isFalse);
    expect(hitObstacle, isTrue);
    expect(bullet.isDestroyed, isTrue);
  });
}
