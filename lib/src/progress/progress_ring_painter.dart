import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The circular indicator's track circle and progress arc. Internal.
class ProgressRingPainter extends CustomPainter {
  /// Creates a ring painter.
  ProgressRingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
    this.rtl = false,
  });

  /// The progress, 0 to 1.
  final double value;

  /// The arc's colour.
  final Color color;

  /// The full circle's colour.
  final Color track;

  /// The stroke's width.
  final double stroke;

  /// Whether the arc sweeps counter-clockwise (right to left).
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final radius = math.max(box.shortestSide / 2 - stroke / 2, 0.0);
    final ring = Rect.fromCircle(center: box.center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(ring.center, radius, paint..color = track);
    if (value <= 0) return;
    canvas.drawArc(
      ring,
      -math.pi / 2,
      (rtl ? -1 : 1) * value * 2 * math.pi,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(ProgressRingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke ||
      old.rtl != rtl;
}
