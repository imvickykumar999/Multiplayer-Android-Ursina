import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

class ArenaBox {
  final Vector3 center;
  final Vector3 scale;
  final String textureType; // 'floor', 'wall', 'stair', 'pillar', 'railing', 'cover'
  final Color baseColor;

  const ArenaBox({
    required this.center,
    required this.scale,
    this.textureType = 'wall',
    this.baseColor = const Color(0xFF888888),
  });

  double get minX => center.x - scale.x / 2.0;
  double get maxX => center.x + scale.x / 2.0;
  double get minY => center.y - scale.y / 2.0;
  double get maxY => center.y + scale.y / 2.0;
  double get minZ => center.z - scale.z / 2.0;
  double get maxZ => center.z + scale.z / 2.0;
}

class MapData {
  static final List<Vector3> spawnPoints = [
    Vector3(0, 1, 0),
    Vector3(12, 1, 0),
    Vector3(0, 1, 12),
    Vector3(12, 1, 12),
    Vector3(-6, 1, -6),
    Vector3(6, 1, -6),
    // 1st Floor spawn points
    Vector3(0, 6, 14),
    Vector3(0, 6, -14),
    Vector3(16, 6, 0),
    Vector3(-16, 6, 0),
  ];

  static List<ArenaBox> getArenaBoxes() {
    final List<ArenaBox> boxes = [];

    // Ground Floor: 40x40 from -20 to 20, center Y = 0.5, thickness 1.0 (top surface at Y = 1.0)
    boxes.add(ArenaBox(
      center: Vector3(0, 0.5, 0),
      scale: Vector3(40, 1.0, 40),
      textureType: 'floor',
      baseColor: const Color(0xFFC0A080),
    ));

    // 1st Floor Slabs (height Y = 6.0, slab center at 5.75, thick 0.5)
    // North platform: X: [-20, 20], Z: [6, 20]
    boxes.add(ArenaBox(
      center: Vector3(0, 5.75, 13),
      scale: Vector3(40, 0.5, 14),
      textureType: 'floor',
      baseColor: const Color(0xFFB09070),
    ));

    // South platform: X: [-20, 20], Z: [-20, -6]
    boxes.add(ArenaBox(
      center: Vector3(0, 5.75, -13),
      scale: Vector3(40, 0.5, 14),
      textureType: 'floor',
      baseColor: const Color(0xFFB09070),
    ));

    // East walkway: X: [12, 20], Z: [-6, 6]
    boxes.add(ArenaBox(
      center: Vector3(16, 5.75, 0),
      scale: Vector3(8, 0.5, 12),
      textureType: 'floor',
      baseColor: const Color(0xFFB09070),
    ));

    // West walkway: X: [-20, -12], Z: [-6, 6]
    boxes.add(ArenaBox(
      center: Vector3(-16, 5.75, 0),
      scale: Vector3(8, 0.5, 12),
      textureType: 'floor',
      baseColor: const Color(0xFFB09070),
    ));

    // Stair 1 (East flank at X = 8.5): 10 steps climbing +Z
    for (int i = 0; i < 10; i++) {
      boxes.add(ArenaBox(
        center: Vector3(8.5, 1.25 + i * 0.5, -3.5 + i * 1.0),
        scale: Vector3(3.5, 0.5, 1.0),
        textureType: 'stair',
        baseColor: const Color(0xFFBBAA88),
      ));
    }

    // Stair 2 (West flank at X = -8.5): 10 steps climbing -Z
    for (int i = 0; i < 10; i++) {
      boxes.add(ArenaBox(
        center: Vector3(-8.5, 1.25 + i * 0.5, 3.5 - i * 1.0),
        scale: Vector3(3.5, 0.5, 1.0),
        textureType: 'stair',
        baseColor: const Color(0xFFBBAA88),
      ));
    }

    // 4 Architectural Support Pillars
    boxes.add(ArenaBox(center: Vector3(12, 3.5, 6), scale: Vector3(1, 5, 1), textureType: 'pillar', baseColor: const Color(0xFF7A6855)));
    boxes.add(ArenaBox(center: Vector3(12, 3.5, -6), scale: Vector3(1, 5, 1), textureType: 'pillar', baseColor: const Color(0xFF7A6855)));
    boxes.add(ArenaBox(center: Vector3(-12, 3.5, 6), scale: Vector3(1, 5, 1), textureType: 'pillar', baseColor: const Color(0xFF7A6855)));
    boxes.add(ArenaBox(center: Vector3(-12, 3.5, -6), scale: Vector3(1, 5, 1), textureType: 'pillar', baseColor: const Color(0xFF7A6855)));

    // Railings along atrium perimeter
    boxes.add(ArenaBox(center: Vector3(12, 6.5, 0), scale: Vector3(0.4, 1.0, 12), textureType: 'railing', baseColor: const Color(0xFF554433)));
    boxes.add(ArenaBox(center: Vector3(-12, 6.5, 0), scale: Vector3(0.4, 1.0, 12), textureType: 'railing', baseColor: const Color(0xFF554433)));
    boxes.add(ArenaBox(center: Vector3(-2.625, 6.5, 6), scale: Vector3(18.75, 1.0, 0.4), textureType: 'railing', baseColor: const Color(0xFF554433)));
    boxes.add(ArenaBox(center: Vector3(11.125, 6.5, 6), scale: Vector3(1.75, 1.0, 0.4), textureType: 'railing', baseColor: const Color(0xFF554433)));
    boxes.add(ArenaBox(center: Vector3(2.625, 6.5, -6), scale: Vector3(18.75, 1.0, 0.4), textureType: 'railing', baseColor: const Color(0xFF554433)));
    boxes.add(ArenaBox(center: Vector3(-11.125, 6.5, -6), scale: Vector3(1.75, 1.0, 0.4), textureType: 'railing', baseColor: const Color(0xFF554433)));

    // 1st Floor Tactical Cover Barricades
    boxes.add(ArenaBox(center: Vector3(0, 7.5, 15), scale: Vector3(4, 3.0, 1.0), textureType: 'cover', baseColor: const Color(0xFF6E5D4C)));
    boxes.add(ArenaBox(center: Vector3(0, 7.5, -15), scale: Vector3(4, 3.0, 1.0), textureType: 'cover', baseColor: const Color(0xFF6E5D4C)));

    // Map Walls from map.py
    // Corner hiding bunkers:
    boxes.add(ArenaBox(center: Vector3(16, 3.0, 13), scale: Vector3(1.5, 4, 6), textureType: 'wall', baseColor: const Color(0xFF8B7355)));
    boxes.add(ArenaBox(center: Vector3(13, 3.0, 16), scale: Vector3(6, 4, 1.5), textureType: 'wall', baseColor: const Color(0xFF8B7355)));

    boxes.add(ArenaBox(center: Vector3(-16, 3.0, 13), scale: Vector3(1.5, 4, 6), textureType: 'wall', baseColor: const Color(0xFF8B7355)));
    boxes.add(ArenaBox(center: Vector3(-13, 3.0, 16), scale: Vector3(6, 4, 1.5), textureType: 'wall', baseColor: const Color(0xFF8B7355)));

    boxes.add(ArenaBox(center: Vector3(-16, 3.0, -13), scale: Vector3(1.5, 4, 6), textureType: 'wall', baseColor: const Color(0xFF8B7355)));
    boxes.add(ArenaBox(center: Vector3(-13, 3.0, -16), scale: Vector3(6, 4, 1.5), textureType: 'wall', baseColor: const Color(0xFF8B7355)));

    boxes.add(ArenaBox(center: Vector3(16, 3.0, -13), scale: Vector3(1.5, 4, 6), textureType: 'wall', baseColor: const Color(0xFF8B7355)));
    boxes.add(ArenaBox(center: Vector3(13, 3.0, -16), scale: Vector3(6, 4, 1.5), textureType: 'wall', baseColor: const Color(0xFF8B7355)));

    // Perimeter mid-lane cover:
    boxes.add(ArenaBox(center: Vector3(-15, 2.75, 0), scale: Vector3(1.5, 3.5, 4), textureType: 'wall', baseColor: const Color(0xFF8B7355)));
    boxes.add(ArenaBox(center: Vector3(0, 2.75, -15), scale: Vector3(4, 3.5, 1.5), textureType: 'wall', baseColor: const Color(0xFF8B7355)));

    // Center tactical barricades:
    boxes.add(ArenaBox(center: Vector3(-4, 2.5, 3), scale: Vector3(3.5, 3, 1.2), textureType: 'wall', baseColor: const Color(0xFF8B7355)));
    boxes.add(ArenaBox(center: Vector3(4, 2.5, -3), scale: Vector3(3.5, 3, 1.2), textureType: 'wall', baseColor: const Color(0xFF8B7355)));

    return boxes;
  }
}
