import 'package:flutter_test/flutter_test.dart';
import 'package:game/models/bullet.dart';
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
      (_, _) {},
      player: player,
      onHitPlayer: (_, damage) => reportedDamage = damage,
    );

    expect(alive, isFalse);
    expect(reportedDamage, 25);
    expect(bullet.isDestroyed, isTrue);
  });
}
