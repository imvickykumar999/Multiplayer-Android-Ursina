import 'package:flutter/material.dart';

typedef JoystickCallback = void Function(double x, double y);

class VirtualJoystick extends StatefulWidget {
  final double radius;
  final double stickRadius;
  final JoystickCallback onChange;

  const VirtualJoystick({
    super.key,
    this.radius = 60.0,
    this.stickRadius = 26.0,
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

    final normX = (_dragOffset.dx / widget.radius).clamp(-1.0, 1.0);
    final normY = (_dragOffset.dy / widget.radius).clamp(-1.0, 1.0);
    // Y is inverted for forward/backward: drag up -> forward (positive Z)
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
          color: Colors.black.withAlpha(90),
          border: Border.all(color: Colors.white.withAlpha(80), width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(120),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Transform.translate(
            offset: _dragOffset,
            child: Container(
              width: widget.stickRadius * 2,
              height: widget.stickRadius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF64B5F6),
                    Color(0xFF1976D2),
                  ],
                ),
                border: Border.all(color: Colors.white, width: 2.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withAlpha(120),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
