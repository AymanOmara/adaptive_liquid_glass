import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The capacity ring gauge's tinted track circle and its fill arc. Internal.
class GaugeRingPainter extends CustomPainter {
  /// Creates the capacity ring painter.
  GaugeRingPainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.stroke,
    this.rtl = false,
  });

  /// The fill's share of the ring, 0 to 1.
  final double fraction;

  /// The fill arc's colour.
  final Color color;

  /// The full ring's colour.
  final Color track;

  /// The ring's stroke width.
  final double stroke;

  /// Whether the arc sweeps counterclockwise (right to left).
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
    if (fraction <= 0) return;
    canvas.drawArc(
      ring,
      -math.pi / 2,
      (rtl ? -1 : 1) * fraction * 2 * math.pi,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(GaugeRingPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke ||
      old.rtl != rtl;
}
