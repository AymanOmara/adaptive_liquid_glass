import 'package:flutter/widgets.dart';

import 'list_metrics.dart';

part 'list_chevron_painter.dart';

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
