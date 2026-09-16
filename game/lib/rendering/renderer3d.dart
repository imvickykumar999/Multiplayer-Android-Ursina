import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../models/player.dart';
import '../models/enemy.dart';
import '../models/bullet.dart';
import '../models/map_data.dart';

class RenderFace {
  final List<Offset> points;
  final double depth;
  final Color color;
  final Color? borderColor;
  final bool upperFloorTop;

  RenderFace({
    required this.points,
    required this.depth,
    required this.color,
    this.borderColor,
    this.upperFloorTop = false,
  });
}

class ArenaRenderer3D extends CustomPainter {
  final Player player;
  final List<Enemy> enemies;
  final List<Bullet> bullets;
  final List<ArenaBox> arenaBoxes;
  final double muzzleFlashTimer;
  final double fov; // in degrees

  ArenaRenderer3D({
    required this.player,
    required this.enemies,
    required this.bullets,
    required this.arenaBoxes,
    this.muzzleFlashTimer = 0.0,
    this.fov = 75.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Draw Sky Backdrop (Atmospheric sky gradient panning with pitch & yaw)
    _drawSky(canvas, width, height);

    // 2. Camera setup
    // Camera eye position: player position + eye offset (1.4 units up)
    final camPos = vm.Vector3(
      player.position.x,
      player.position.y + 1.4,
      player.position.z,
    );
    final yawRad = player.yaw * pi / 180.0;
    final pitchRad = player.pitch * pi / 180.0;

    // Camera basis vectors
    final forward = vm.Vector3(
      sin(yawRad) * cos(pitchRad),
      sin(pitchRad),
      cos(yawRad) * cos(pitchRad),
    )..normalize();

    final right = vm.Vector3(cos(yawRad), 0, -sin(yawRad))..normalize();
    final up = vm.Vector3.zero();
    right.crossInto(forward, up);
    up.normalize();
    // In our coordinate system, cross(R, F) points down, so negate up to make it point up
    up.negate();

    final fovRad = fov * pi / 180.0;
    final focalLength = (width / 2.0) / tan(fovRad / 2.0);

    const nearPlane = 0.2;
    final List<RenderFace> facesToDraw = [];

    // Light source vector
    final lightDir = vm.Vector3(0.3, 0.9, -0.4)..normalize();

    // 3. Build geometry for Arena Boxes (Floors, Walls, Slabs, Stairs, Pillars)
    for (final box in arenaBoxes) {
      _generateBoxFaces(
        box: box,
        camPos: camPos,
        right: right,
        up: up,
        forward: forward,
        width: width,
        height: height,
        focalLength: focalLength,
        nearPlane: nearPlane,
        lightDir: lightDir,
        facesOut: facesToDraw,
      );
    }

    // 4. Build geometry for Remote Enemy Players
    for (final enemy in enemies) {
      if (enemy.isDead || enemy.health <= 0) continue;

      // Enemy body cube (1.0 x 1.8 x 1.0)
      final bodyBox = ArenaBox(
        center: vm.Vector3(
          enemy.position.x,
          enemy.position.y + 0.9,
          enemy.position.z,
        ),
        scale: vm.Vector3(1.0, 1.8, 1.0),
        textureType: 'enemy',
        baseColor: enemy.color,
      );
      _generateBoxFaces(
        box: bodyBox,
        camPos: camPos,
        right: right,
        up: up,
        forward: forward,
        width: width,
        height: height,
        focalLength: focalLength,
        nearPlane: nearPlane,
        lightDir: lightDir,
        facesOut: facesToDraw,
      );

      // Enemy gun attached to right side
      final yawE = enemy.rotationY * pi / 180.0;
      final eFwd = vm.Vector3(sin(yawE), 0, cos(yawE));
      final eRight = vm.Vector3(cos(yawE), 0, -sin(yawE));
      final gunPos =
          enemy.position + vm.Vector3(0, 1.0, 0) + eRight * 0.6 + eFwd * 0.4;
      final gunBox = ArenaBox(
        center: gunPos,
        scale: vm.Vector3(0.2, 0.2, 0.7),
        textureType: 'enemy_gun',
        baseColor: enemy.color,
      );
      _generateBoxFaces(
        box: gunBox,
        camPos: camPos,
        right: right,
        up: up,
        forward: forward,
        width: width,
        height: height,
        focalLength: focalLength,
        nearPlane: nearPlane,
        lightDir: lightDir,
        facesOut: facesToDraw,
      );
    }

    // 5. Build geometry for Bullets
    for (final bullet in bullets) {
      if (bullet.isDestroyed) continue;
      _generateBulletFaces(
        bullet: bullet,
        camPos: camPos,
        right: right,
        up: up,
        forward: forward,
        width: width,
        height: height,
        focalLength: focalLength,
        nearPlane: nearPlane,
        facesOut: facesToDraw,
      );
    }

    // 6. Sort faces by depth (farthest first). Upper-floor tops get a stable
    // occlusion layer so the ground floor cannot bleed through them at steep
    // camera angles where average polygon depth is ambiguous.
    facesToDraw.sort((a, b) {
      if (a.upperFloorTop != b.upperFloorTop) {
        return a.upperFloorTop ? 1 : -1;
      }
      return b.depth.compareTo(a.depth);
    });

    // 7. Render all sorted faces
    final paint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final face in facesToDraw) {
      if (face.points.length < 3) continue;

      final path = Path()..moveTo(face.points[0].dx, face.points[0].dy);
      for (int i = 1; i < face.points.length; i++) {
        path.lineTo(face.points[i].dx, face.points[i].dy);
      }
      path.close();

      paint.color = face.color;
      canvas.drawPath(path, paint);

      if (face.borderColor != null) {
        borderPaint.color = face.borderColor!;
        canvas.drawPath(path, borderPaint);
      }
    }

    // 8. Render Billboarded Name Tags for Enemies
    _drawEnemyNameTags(
      canvas,
      camPos,
      right,
      up,
      forward,
      width,
      height,
      focalLength,
    );

    // 9. Render Local Player Gun Viewmodel & Muzzle Flash
    if (player.health > 0) {
      _drawViewmodelGun(canvas, width, height);
    }

    // 10. Center Crosshair
    _drawCrosshair(canvas, width, height);
  }

  void _drawSky(Canvas canvas, double width, double height) {
    // Horizon offset based on pitch angle
    final pitchFraction = (player.pitch / 90.0);
    final horizonY = height / 2.0 + pitchFraction * (height / 2.0);

    // Sky gradient
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
        colors: [
          const Color(0xFF0F2035), // Deep sky blue
          const Color(0xFF28547A), // Sky mid
          const Color(0xFF5A7B96), // Horizon haze
          const Color(0xFF333E48), // Ground fog
          const Color(0xFF1B2228), // Deep ground
        ],
      ).createShader(Rect.fromLTWH(0, horizonY - height, width, height * 2));

    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), skyPaint);
  }

  void _generateBoxFaces({
    required ArenaBox box,
    required vm.Vector3 camPos,
    required vm.Vector3 right,
    required vm.Vector3 up,
    required vm.Vector3 forward,
    required double width,
    required double height,
    required double focalLength,
    required double nearPlane,
    required vm.Vector3 lightDir,
    required List<RenderFace> facesOut,
  }) {
    final minX = box.minX;
    final maxX = box.maxX;
    final minY = box.minY;
    final maxY = box.maxY;
    final minZ = box.minZ;
    final maxZ = box.maxZ;

    // 8 box vertices in world space
    final v000 = vm.Vector3(minX, minY, minZ);
    final v001 = vm.Vector3(minX, minY, maxZ);
    final v010 = vm.Vector3(minX, maxY, minZ);
    final v011 = vm.Vector3(minX, maxY, maxZ);
    final v100 = vm.Vector3(maxX, minY, minZ);
    final v101 = vm.Vector3(maxX, minY, maxZ);
    final v110 = vm.Vector3(maxX, maxY, minZ);
    final v111 = vm.Vector3(maxX, maxY, maxZ);

    // Define 6 faces (normal, vertices in CCW order)
    final faces = [
      // Top (+Y)
      _FaceDef(vm.Vector3(0, 1, 0), [v010, v110, v111, v011], 0.2),
      // Bottom (-Y)
      _FaceDef(vm.Vector3(0, -1, 0), [v001, v101, v100, v000], -0.2),
      // Front (+Z)
      _FaceDef(vm.Vector3(0, 0, 1), [v001, v101, v111, v011], 0.0),
      // Back (-Z)
      _FaceDef(vm.Vector3(0, 0, -1), [v100, v000, v010, v110], -0.1),
      // Right (+X)
      _FaceDef(vm.Vector3(1, 0, 0), [v101, v100, v110, v111], 0.1),
      // Left (-X)
      _FaceDef(vm.Vector3(-1, 0, 0), [v000, v001, v011, v010], -0.1),
    ];

    for (final face in faces) {
      // 1. Backface culling
      final faceCenter = (face.verts[0] + face.verts[2]) * 0.5;
      final toCam = camPos - faceCenter;
      if (face.normal.dot(toCam) <= 0) continue; // Facing away

      // 2. Transform vertices to Camera Space
      final camVerts = <vm.Vector3>[];
      for (final v in face.verts) {
        final d = v - camPos;
        camVerts.add(vm.Vector3(d.dot(right), d.dot(up), d.dot(forward)));
      }

      // 3. Clip polygon against near plane camZ >= nearPlane
      final clipped = _clipPolygonNearPlane(camVerts, nearPlane);
      if (clipped.length < 3) continue;

      // 4. Project clipped vertices to screen coordinates
      double sumZ = 0.0;
      final screenPoints = <Offset>[];
      for (final cv in clipped) {
        sumZ += cv.z;
        final sx = width / 2.0 + (cv.x / cv.z) * focalLength;
        final sy = height / 2.0 - (cv.y / cv.z) * focalLength;
        screenPoints.add(Offset(sx, sy));
      }

      final avgDepth = sumZ / clipped.length;

      // 5. Lighting calculation
      final diffuse = max(0.0, face.normal.dot(lightDir));
      final intensity = (0.4 + diffuse * 0.6 + face.shadeModifier).clamp(
        0.2,
        1.0,
      );

      final baseR = (box.baseColor.r * 255.0).round().clamp(0, 255);
      final baseG = (box.baseColor.g * 255.0).round().clamp(0, 255);
      final baseB = (box.baseColor.b * 255.0).round().clamp(0, 255);
      final r = (baseR * intensity).toInt().clamp(0, 255);
      final g = (baseG * intensity).toInt().clamp(0, 255);
      final b = (baseB * intensity).toInt().clamp(0, 255);
      final faceColor = Color.fromARGB(255, r, g, b);

      Color? borderColor;
      if (box.textureType == 'wall' ||
          box.textureType == 'pillar' ||
          box.textureType == 'stair') {
        borderColor = Color.fromARGB(
          160,
          (r * 0.7).toInt(),
          (g * 0.7).toInt(),
          (b * 0.7).toInt(),
        );
      } else if (box.textureType == 'floor') {
        borderColor = Color.fromARGB(
          80,
          (r * 0.85).toInt(),
          (g * 0.85).toInt(),
          (b * 0.85).toInt(),
        );
      }

      facesOut.add(
        RenderFace(
          points: screenPoints,
          depth: avgDepth,
          color: faceColor,
          borderColor: borderColor,
          upperFloorTop:
              box.textureType == 'floor' &&
              box.center.y > 1.0 &&
              face.normal.y > 0,
        ),
      );
    }
  }

  void _generateBulletFaces({
    required Bullet bullet,
    required vm.Vector3 camPos,
    required vm.Vector3 right,
    required vm.Vector3 up,
    required vm.Vector3 forward,
    required double width,
    required double height,
    required double focalLength,
    required double nearPlane,
    required List<RenderFace> facesOut,
  }) {
    final d = bullet.position - camPos;
    final cz = d.dot(forward);
    if (cz < nearPlane) return;

    final cx = d.dot(right);
    final cy = d.dot(up);

    final sx = width / 2.0 + (cx / cz) * focalLength;
    final sy = height / 2.0 - (cy / cz) * focalLength;
    final radius = max(2.0, (0.35 / cz) * focalLength);

    // Represent bullet as an octagonal billboard face
    final points = <Offset>[];
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4.0;
      points.add(Offset(sx + cos(angle) * radius, sy + sin(angle) * radius));
    }

    facesOut.add(
      RenderFace(
        points: points,
        depth: cz,
        color: const Color(0xFFFFEB3B),
        borderColor: const Color(0xFFFF9800),
      ),
    );
  }

  List<vm.Vector3> _clipPolygonNearPlane(List<vm.Vector3> verts, double nearZ) {
    final outList = <vm.Vector3>[];
    for (int i = 0; i < verts.length; i++) {
      final cur = verts[i];
      final next = verts[(i + 1) % verts.length];

      final curIn = cur.z >= nearZ;
      final nextIn = next.z >= nearZ;

      if (curIn && nextIn) {
        outList.add(next);
      } else if (curIn && !nextIn) {
        final t = (nearZ - cur.z) / (next.z - cur.z);
        outList.add(
          vm.Vector3(
            cur.x + (next.x - cur.x) * t,
            cur.y + (next.y - cur.y) * t,
            nearZ,
          ),
        );
      } else if (!curIn && nextIn) {
        final t = (nearZ - cur.z) / (next.z - cur.z);
        outList.add(
          vm.Vector3(
            cur.x + (next.x - cur.x) * t,
            cur.y + (next.y - cur.y) * t,
            nearZ,
          ),
        );
        outList.add(next);
      }
    }
    return outList;
  }

  void _drawEnemyNameTags(
    Canvas canvas,
    vm.Vector3 camPos,
    vm.Vector3 right,
    vm.Vector3 up,
    vm.Vector3 forward,
    double width,
    double height,
    double focalLength,
  ) {
    for (final enemy in enemies) {
      if (enemy.isDead || enemy.health <= 0) continue;

      final headPos = vm.Vector3(
        enemy.position.x,
        enemy.position.y + 2.3,
        enemy.position.z,
      );
      final d = headPos - camPos;
      final cz = d.dot(forward);
      if (cz < 0.5) continue; // Behind or too close

      final cx = d.dot(right);
      final cy = d.dot(up);

      final sx = width / 2.0 + (cx / cz) * focalLength;
      final sy = height / 2.0 - (cy / cz) * focalLength;

      // Draw floating billboard name tag
      final textSpan = TextSpan(
        text: '${enemy.username} [${enemy.health}/250]',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
          ],
        ),
      );

      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();

      final bgRect = Rect.fromCenter(
        center: Offset(sx, sy),
        width: tp.width + 12,
        height: tp.height + 6,
      );

      final bgPaint = Paint()..color = Colors.black.withAlpha(160);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        bgPaint,
      );

      // Mini health bar under name tag
      final healthPct = (enemy.health / 250.0).clamp(0.0, 1.0);
      final hpBarRect = Rect.fromLTWH(
        bgRect.left + 2,
        bgRect.bottom + 2,
        bgRect.width - 4,
        3,
      );
      canvas.drawRect(hpBarRect, Paint()..color = Colors.red);
      canvas.drawRect(
        Rect.fromLTWH(
          hpBarRect.left,
          hpBarRect.top,
          hpBarRect.width * healthPct,
          hpBarRect.height,
        ),
        Paint()..color = Colors.greenAccent,
      );

      tp.paint(canvas, Offset(sx - tp.width / 2.0, sy - tp.height / 2.0));
    }
  }

  void _drawViewmodelGun(Canvas canvas, double width, double height) {
    final gunBaseX = width * 0.76;
    final gunBaseY = height * 0.78;

    // Recoil and reload offsets
    double recoilY = 0.0;
    double recoilX = 0.0;
    double reloadRot = 0.0;

    if (muzzleFlashTimer > 0) {
      recoilY = -12.0 * (muzzleFlashTimer / 0.08);
      recoilX = -4.0 * (muzzleFlashTimer / 0.08);
    }

    if (player.isReloading) {
      final prog = (player.reloadTimer / player.reloadTime);
      reloadRot = sin(prog * pi) * 0.4; // Tilt gun down during reload
    }

    canvas.save();
    canvas.translate(gunBaseX + recoilX, gunBaseY + recoilY);
    canvas.rotate(reloadRot);

    // Gun body & barrel
    final gunPaint = Paint()..color = player.color;
    final darkMetalPaint = Paint()..color = const Color(0xFF222831);
    final highlightPaint = Paint()..color = const Color(0xFF393E46);

    // Main receiver
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-20, 20, 90, 45),
        const Radius.circular(5),
      ),
      gunPaint,
    );

    // Barrel
    canvas.drawRect(const Rect.fromLTWH(70, 28, 70, 16), darkMetalPaint);
    canvas.drawRect(const Rect.fromLTWH(135, 26, 12, 20), highlightPaint);

    // Gun sights & top rail
    canvas.drawRect(const Rect.fromLTWH(-10, 14, 80, 7), highlightPaint);
    canvas.drawRect(const Rect.fromLTWH(138, 18, 4, 8), highlightPaint);

    // Grip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, 60, 35, 70),
        const Radius.circular(4),
      ),
      darkMetalPaint,
    );

    // Muzzle flash if firing
    if (muzzleFlashTimer > 0) {
      final flashPaint = Paint()..color = const Color(0xFFFFD54F);
      final centerFlash = const Offset(150, 36);

      final flashPath = Path();
      const flashSize = 35.0;
      for (int i = 0; i < 8; i++) {
        final angle = i * pi / 4.0;
        final r = (i % 2 == 0) ? flashSize : flashSize * 0.4;
        final pt = Offset(
          centerFlash.dx + cos(angle) * r,
          centerFlash.dy + sin(angle) * r,
        );
        if (i == 0) {
          flashPath.moveTo(pt.dx, pt.dy);
        } else {
          flashPath.lineTo(pt.dx, pt.dy);
        }
      }
      flashPath.close();
      canvas.drawPath(flashPath, flashPaint);

      final innerFlashPaint = Paint()..color = Colors.white;
      canvas.drawCircle(centerFlash, 8.0, innerFlashPaint);
    }

    canvas.restore();
  }

  void _drawCrosshair(Canvas canvas, double width, double height) {
    final cx = width / 2.0;
    final cy = height / 2.0;

    final crosshairPaint = Paint()
      ..color = const Color.fromRGBO(255, 0, 0, 0.7)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    const gap = 4.0;
    const len = 12.0;

    // Center dot
    canvas.drawCircle(Offset(cx, cy), 2.0, crosshairPaint);

    // 4 reticle ticks
    canvas.drawLine(
      Offset(cx - gap - len, cy),
      Offset(cx - gap, cy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(cx + gap, cy),
      Offset(cx + gap + len, cy),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(cx, cy - gap - len),
      Offset(cx, cy - gap),
      crosshairPaint,
    );
    canvas.drawLine(
      Offset(cx, cy + gap),
      Offset(cx, cy + gap + len),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ArenaRenderer3D oldDelegate) => true;
}

class _FaceDef {
  final vm.Vector3 normal;
  final List<vm.Vector3> verts;
  final double shadeModifier;
  _FaceDef(this.normal, this.verts, this.shadeModifier);
}
