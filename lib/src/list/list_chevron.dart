import 'package:flutter/widgets.dart';

import 'list_metrics.dart';

/// Internal. The list row's disclosure chevron, drawn as iOS does: a
/// stroked open chevron rather than a font glyph, so it matches SF
/// Symbols' weight and rounding.
class ListChevron extends StatelessWidget {
  /// Creates the chevron.
  const ListChevron({super.key, required this.color});

  /// The stroke's colour.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final chevron = SizedBox(
      width: ListMetrics.chevronWidth,
      height: ListMetrics.chevronHeight,
      child: CustomPaint(painter: _ChevronPainter(color)),
    );
    // The disclosure points into the content, so it mirrors in RTL.
    return Directionality.of(context) == TextDirection.rtl
        ? Transform.flip(flipX: true, child: chevron)
        : chevron;
  }
}

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // An open chevron hugging the glyph box; the stroke is inset by half
    // its width so the round caps stay inside the measured bounds.
    final s = ListMetrics.chevronStroke;
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
