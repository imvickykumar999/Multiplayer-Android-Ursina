import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;
import '../models/player.dart';
import '../models/enemy.dart';

class TacticalMinimap extends StatelessWidget {
  final Player player;
  final List<Enemy> enemies;
  final double size;

  const TacticalMinimap({
    super.key,
    required this.player,
    required this.enemies,
    this.size = 104.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF07111E).withValues(alpha: 0.85),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 10,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.cyanAccent.withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: _MinimapPainter(player: player, enemies: enemies),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final Player player;
  final List<Enemy> enemies;

  _MinimapPainter({required this.player, required this.enemies});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final radius = size.width / 2.0;

    // Scale: arena is roughly 40x40 units. Let 30 units = radius * 0.85
    final scale = (radius * 0.85) / 24.0;

    // 1. Concentric radar sweep rings
    final gridPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(Offset(cx, cy), radius * 0.45, gridPaint);
    canvas.drawCircle(Offset(cx, cy), radius * 0.80, gridPaint);

    // Crosshairs
    canvas.drawLine(Offset(cx, 4), Offset(cx, size.height - 4), gridPaint);
    canvas.drawLine(Offset(4, cy), Offset(size.width - 4, cy), gridPaint);

    // Save canvas and rotate so player's heading is always pointing straight UP
    canvas.save();
    canvas.translate(cx, cy);
    final playerYawRad = player.yaw * pi / 180.0;
    canvas.rotate(-playerYawRad);

    // 2. Draw Arena Outline in player-relative coordinate space
    final arenaPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Arena boundary is -20 to 20 in X and Z
    final pX = player.position.x;
    final pZ = player.position.z;

    final arenaLeft = (-20.0 - pX) * scale;
    final arenaRight = (20.0 - pX) * scale;
    // Note: in 3D, Z is forward; on screen, Y goes down, so let screen Y = -Z * scale
    final arenaTop = -(20.0 - pZ) * scale;
    final arenaBottom = -(-20.0 - pZ) * scale;

    canvas.drawRect(
      Rect.fromLTRB(arenaLeft, arenaTop, arenaRight, arenaBottom),
      arenaPaint,
    );

    // Upper deck atrium boundary (-6 to 6 in X and Z)
    final atriumLeft = (-6.0 - pX) * scale;
    final atriumRight = (6.0 - pX) * scale;
    final atriumTop = -(6.0 - pZ) * scale;
    final atriumBottom = -(-6.0 - pZ) * scale;
    canvas.drawRect(
      Rect.fromLTRB(atriumLeft, atriumTop, atriumRight, atriumBottom),
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 3. Draw Remote Enemies / Bots
    for (final enemy in enemies) {
      if (enemy.isDead || enemy.health <= 0) continue;

      final relX = (enemy.position.x - pX) * scale;
      final relY = -(enemy.position.z - pZ) * scale;

      // Clamp within radar circle
      final distFromCenter = sqrt(relX * relX + relY * relY);
      final clampedDist = min(distFromCenter, radius - 6.0);
      final angle = atan2(relY, relX);
      final drawX = cos(angle) * clampedDist;
      final drawY = sin(angle) * clampedDist;

      final enemyPaint = Paint()
        ..color = enemy.color
        ..style = PaintingStyle.fill;

      // Elevation indicator:
      // If enemy is significantly higher than player, draw upward triangle
      if (enemy.position.y - player.position.y > 2.0) {
        final path = Path()
          ..moveTo(drawX, drawY - 4.0)
          ..lineTo(drawX - 3.5, drawY + 3.0)
          ..lineTo(drawX + 3.5, drawY + 3.0)
          ..close();
        canvas.drawPath(path, enemyPaint);
      } else if (player.position.y - enemy.position.y > 2.0) {
        // Significantly lower
        final path = Path()
          ..moveTo(drawX, drawY + 4.0)
          ..lineTo(drawX - 3.5, drawY - 3.0)
          ..lineTo(drawX + 3.5, drawY - 3.0)
          ..close();
        canvas.drawPath(path, enemyPaint);
      } else {
        // Same level: circle
        canvas.drawCircle(Offset(drawX, drawY), 3.5, enemyPaint);
        canvas.drawCircle(
          Offset(drawX, drawY),
          3.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    canvas.restore();

    // 4. Draw Player Indicator in center (pointing UP)
    final playerArrow = Path()
      ..moveTo(cx, cy - 6.0)
      ..lineTo(cx - 4.5, cy + 5.0)
      ..lineTo(cx, cy + 2.5)
      ..lineTo(cx + 4.5, cy + 5.0)
      ..close();

    canvas.drawPath(
      playerArrow,
      Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      playerArrow,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // North cardinal mark
    final northAngle = -playerYawRad - (pi / 2.0);
    final nX = cx + cos(northAngle) * (radius - 8.0);
    final nY = cy + sin(northAngle) * (radius - 8.0);
    const nSpan = TextSpan(
      text: 'N',
      style: TextStyle(
        color: Colors.cyanAccent,
        fontSize: 9,
        fontWeight: FontWeight.w900,
      ),
    );
    final nTp = TextPainter(text: nSpan, textDirection: TextDirection.ltr)
      ..layout();
    nTp.paint(canvas, Offset(nX - nTp.width / 2.0, nY - nTp.height / 2.0));
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) => true;
}
