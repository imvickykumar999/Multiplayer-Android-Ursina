import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class FloatingDamage {
  vm.Vector3 position;
  final String text;
  final bool isHeadshot;
  final bool isPlayerTakingDamage;
  double lifetime;
  final double maxLifetime;

  FloatingDamage({
    required this.position,
    required this.text,
    this.isHeadshot = false,
    this.isPlayerTakingDamage = false,
    this.lifetime = 0.85,
  }) : maxLifetime = lifetime;

  bool update(double dt) {
    // Float upward in world space
    position.y += 1.6 * dt;
    lifetime -= dt;
    return lifetime > 0;
  }
}
