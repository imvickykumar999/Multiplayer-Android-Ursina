import 'package:flutter/material.dart';

typedef JoystickCallback = void Function(double x, double y);

class VirtualJoystick extends StatefulWidget {
  final double radius;
  final double stickRadius;
  final JoystickCallback onChange;

  const VirtualJoystick({
    super.key,
    this.radius = 65.0,
    this.stickRadius = 28.0,
    required this.onChange,
  });

  @override
  State<VirtualJoystick> createState() => _VirtualJoystickState();
}

class _VirtualJoystickState extends State<VirtualJoystick> {
  Offset _dragOffset = Offset.zero;

  void _updatePosition(Offset localPos, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final delta = localPos - center;
    final dist = delta.distance;

    Offset clampedDelta;
    if (dist > widget.radius) {
      clampedDelta = Offset(
        (delta.dx / dist) * widget.radius,
        (delta.dy / dist) * widget.radius,
      );
    } else {
      clampedDelta = delta;
    }

    setState(() {
      _dragOffset = clampedDelta;
    });

    // Deadzone check
    double normX = (_dragOffset.dx / widget.radius);
    double normY = (_dragOffset.dy / widget.radius);

    if (normX.abs() < 0.05) normX = 0.0;
    if (normY.abs() < 0.05) normY = 0.0;

    normX = normX.clamp(-1.0, 1.0);
    normY = normY.clamp(-1.0, 1.0);

    // Invert Y: dragging upward moves player forward (positive Z)
    widget.onChange(normX, -normY);
  }

  void _reset() {
    setState(() {
      _dragOffset = Offset.zero;
    });
    widget.onChange(0.0, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;

    return GestureDetector(
      onPanStart: (details) {
        _updatePosition(details.localPosition, Size(diameter, diameter));
      },
      onPanUpdate: (details) {
        _updatePosition(details.localPosition, Size(diameter, diameter));
      },
      onPanEnd: (_) => _reset(),
      onPanCancel: () => _reset(),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A1220).withValues(alpha: 0.65),
          border: Border.all(
            color: Colors.cyanAccent.withValues(alpha: 0.35),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Concentric inner ring
            Container(
              width: diameter * 0.55,
              height: diameter * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
              ),
            ),

            // Cardinal tick marks
            Positioned(
              top: 6,
              child: Icon(
                Icons.keyboard_arrow_up,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            Positioned(
              bottom: 6,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            Positioned(
              left: 6,
              child: Icon(
                Icons.keyboard_arrow_left,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            Positioned(
              right: 6,
              child: Icon(
                Icons.keyboard_arrow_right,
                size: 16,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),

            // Draggable Thumbstick with tactical gradient
            Transform.translate(
              offset: _dragOffset,
              child: Container(
                width: widget.stickRadius * 2,
                height: widget.stickRadius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF29B6F6),
                      Color(0xFF0288D1),
                      Color(0xFF01579B),
                    ],
                    stops: [0.0, 0.6, 1.0],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(1, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
