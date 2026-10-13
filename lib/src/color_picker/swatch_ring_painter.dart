import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Paints the ring around a `ColorSwatchDot`: iOS's hue wheel (red at the
/// top, going clockwise) or, with [color], a solid ring.
class SwatchRingPainter extends CustomPainter {
  /// Creates the painter.
  const SwatchRingPainter({required this.width, this.color});

  /// The ring's thickness.
  final double width;

  /// A solid colour; null paints the hue wheel.
  final Color? color;

  static const int _hueStops = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    if (color case final solid?) {
      paint.color = solid;
    } else {
      paint.shader = SweepGradient(
        transform: const GradientRotation(-math.pi / 2),
        colors: [
          for (var i = 0; i < _hueStops; i++)
            HSVColor.fromAHSV(
              1,
              i * 360 / (_hueStops - 1) % 360,
              1,
              1,
            ).toColor(),
        ],
      ).createShader(rect);
    }
    canvas.drawCircle(rect.center, (size.shortestSide - width) / 2, paint);
  }

  @override
  bool shouldRepaint(SwatchRingPainter old) =>
      old.width != width || old.color != color;
}
