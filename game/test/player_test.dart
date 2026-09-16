import 'package:flutter_test/flutter_test.dart';
import 'package:game/models/player.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('ground-floor movement does not snap onto the upper platform', () {
    final player = Player(
      startPos: Vector3(0, 1, 5.8),
      id: '1',
      username: 'Blue',
    );

    player.update(0.1, 0, 1, const []);

    expect(player.position.z, closeTo(6.5, 0.001));
    expect(player.position.y, closeTo(1.0, 0.001));
  });
}