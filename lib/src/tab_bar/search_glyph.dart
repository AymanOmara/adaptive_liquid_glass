import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'tab_bar_metrics.dart';

/// The search tab's magnifying glass (see [TabBarMetrics.searchGlyph]):
/// a ring and a 45° handle with round ends. Not mirrored right to left,
/// like CupertinoIcons.search before it.
class SearchGlyph extends CustomPainter {
  /// Creates the painter.
  const SearchGlyph({required this.color});

  /// The magnifier's ink.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / TabBarMetrics.searchGlyph;
    final stroke = TabBarMetrics.searchStroke * s;
    final r = TabBarMetrics.searchRing * s;
    final centre = Offset(r, r);
    canvas.drawCircle(
      centre,
      r - stroke / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final h = TabBarMetrics.searchHandle * s;
    canvas.drawLine(
      centre + const Offset(1, 1) * ((r - stroke / 2) / math.sqrt2),
      Offset(size.width - h / 2, size.height - h / 2),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = h,
    );
  }

  @override
  bool shouldRepaint(SearchGlyph old) => old.color != color;
}
