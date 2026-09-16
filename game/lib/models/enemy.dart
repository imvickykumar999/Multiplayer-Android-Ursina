import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

const int maxHealth = 250;

final Map<String, Color> colorPalette = {
  "Blue": const Color.fromARGB(255, 52, 152, 219),
  "Green": const Color.fromARGB(255, 46, 204, 113),
  "Orange": const Color.fromARGB(255, 230, 126, 34),
  "Purple": const Color.fromARGB(255, 155, 89, 182),
  "Yellow": const Color.fromARGB(255, 241, 196, 15),
  "Red": const Color.fromARGB(255, 231, 76, 60),
  "Turquoise": const Color.fromARGB(255, 26, 188, 156),
  "Pink": const Color.fromARGB(255, 236, 64, 122),
  "Cyan": const Color.fromARGB(255, 0, 188, 212),
  "Lime": const Color.fromARGB(255, 139, 195, 74),
};

final List<String> colorNames = colorPalette.keys.toList();
final List<Color> playerColors = colorPalette.values.toList();

Color getPlayerColor(String identifier, [String? username]) {
  if (username != null && username.isNotEmpty) {
    final cleanName = username.trim().toLowerCase();
    for (final entry in colorPalette.entries) {
      if (entry.key.toLowerCase() == cleanName) {
        return entry.value;
      }
    }
    for (final entry in colorPalette.entries) {
      if (cleanName.contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
  }

  final idNum = int.tryParse(identifier);
  if (idNum != null) {
    final idx = (idNum - 1).abs() % playerColors.length;
    return playerColors[idx];
  }

  final key = username ?? identifier;
  final idx = key.hashCode.abs() % playerColors.length;
  return playerColors[idx];
}

class Enemy {
  final String id;
  String username;
  Vector3 position;
  double rotationY; // In degrees
  int health;
  bool isDead;
  Color color;

  Enemy({
    required this.id,
    required this.username,
    required this.position,
    this.rotationY = 0.0,
    this.health = maxHealth,
    this.isDead = false,
    Color? color,
  }) : color = color ?? getPlayerColor(id, username);

  void respawn(Vector3 newPos, [int newHealth = maxHealth]) {
    position = newPos.clone();
    health = newHealth;
    isDead = false;
  }
}
