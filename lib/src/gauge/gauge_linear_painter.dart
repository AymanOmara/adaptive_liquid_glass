import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The linear gauge's capsule track and its fill, growing from the
/// start. Internal.
class GaugeLinearPainter extends CustomPainter {
  /// Creates a linear gauge painter.
  GaugeLinearPainter({
    required this.fraction,
    required this.color,
    required this.track,
    this.rtl = false,
  });

  /// The fill's share of the track, 0 to 1.
  final double fraction;

  /// The fill's colour.
  final Color color;

  /// The track's colour.
  final Color track;

  /// Whether the fill grows from the right (right to left).
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final capsule = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(capsule, Paint()..color = track);
    if (fraction <= 0) return;
    final width = math.max(fraction * size.width, size.height);
    canvas.clipRRect(capsule);
    canvas.drawRect(
      rtl
          ? Rect.fromLTWH(size.width - width, 0, width, size.height)
          : Rect.fromLTWH(0, 0, width, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(GaugeLinearPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.rtl != rtl;
}
