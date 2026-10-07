import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'gauge_metrics.dart';

/// The accessory circular gauge's open ring, its gap centred at the
/// bottom, with a dot of the same colour marking the value in a clear
/// gap. Internal.
class GaugeArcPainter extends CustomPainter {
  /// Creates the accessory circular painter.
  GaugeArcPainter({
    required this.fraction,
    required this.color,
    required this.stroke,
    this.rtl = false,
  });

  /// The value's share of the arc, 0 to 1.
  final double fraction;

  /// The ring's and the dot's colour.
  final Color color;

  /// The ring's stroke width.
  final double stroke;

  /// Whether the value runs counterclockwise (right to left).
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final radius = math.max(box.shortestSide / 2 - stroke / 2, 0.0);
    final ring = Rect.fromCircle(center: box.center, radius: radius);
    final sweep = GaugeMetrics.circularSweepDegrees * math.pi / 180;
    // The gap is centred at the bottom (pi / 2 in canvas angles).
    final start = math.pi / 2 + (2 * math.pi - sweep) / 2;
    final angle = rtl
        ? start + sweep - fraction * sweep
        : start + fraction * sweep;
    final dot = Offset(
      ring.center.dx + radius * math.cos(angle),
      ring.center.dy + radius * math.sin(angle),
    );
    // The dot sits in a clear gap cut out of the ring.
    canvas.saveLayer(box.inflate(stroke), Paint());
    canvas.drawArc(
      ring,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    canvas.drawCircle(
      dot,
      GaugeMetrics.circularDotDiameter / 2 + GaugeMetrics.circularDotGap,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
    canvas.drawCircle(
      dot,
      GaugeMetrics.circularDotDiameter / 2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(GaugeArcPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.stroke != stroke ||
      old.rtl != rtl;
}
