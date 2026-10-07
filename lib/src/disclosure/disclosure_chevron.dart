import 'package:flutter/widgets.dart';

import 'disclosure_metrics.dart';

/// Internal. The disclosure group's chevron: the list's stroked chevron,
/// rotating a quarter turn to point down when the group expands.
class DisclosureChevron extends StatelessWidget {
  /// Creates the chevron.
  const DisclosureChevron({
    super.key,
    required this.color,
    required this.turns,
  });

  /// The stroke's colour.
  final Color color;

  /// The chevron's rotation in turns: 0 points toward the row's end;
  /// [DisclosureMetrics.expandedTurns] (clockwise, the mirror in RTL)
  /// points down.
  final Animation<double> turns;

  @override
  Widget build(BuildContext context) {
    final chevron = SizedBox(
      width: DisclosureMetrics.chevronWidth,
      height: DisclosureMetrics.chevronHeight,
      child: CustomPaint(painter: _ChevronPainter(color)),
    );
    // The disclosure points into the content, so it mirrors in RTL; the
    // group then turns it the mirrored way to end pointing down either
    // way.
    // SwiftUI turns the glyph about a point nearer its start than its
    // centre, so the expanded chevron sits a little toward the start.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final pivot =
        2 *
            DisclosureMetrics.chevronPivotStart /
            DisclosureMetrics.chevronWidth -
        1;
    return RotationTransition(
      turns: turns,
      alignment: Alignment(rtl ? -pivot : pivot, 0),
      child: rtl ? Transform.flip(flipX: true, child: chevron) : chevron,
    );
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // An open chevron hugging the glyph box; the stroke is inset by half
    // its width so the round caps stay inside the bounds.
    final s = DisclosureMetrics.chevronStroke;
    final path = Path()
      ..moveTo(s / 2, s / 2)
      ..lineTo(size.width - s / 2, size.height / 2)
      ..lineTo(s / 2, size.height - s / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}
