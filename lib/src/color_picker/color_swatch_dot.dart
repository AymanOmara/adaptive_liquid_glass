import 'package:flutter/widgets.dart';

import 'checkerboard_painter.dart';
import 'color_picker_metrics.dart';
import 'swatch_ring_painter.dart';

/// A round colour swatch like the one at the end of iOS's `ColorPicker`
/// row: a hue-wheel ring, a gap, then the colour (measured from SwiftUI on
/// iOS 26.4: 28 pt, a 3.33 pt ring, a 1.67 pt gap). A translucent colour
/// shows a checkerboard through it.
class ColorSwatchDot extends StatelessWidget {
  /// Creates a swatch.
  const ColorSwatchDot({
    super.key,
    required this.color,
    this.size = ColorPickerMetrics.rowSwatch,
    this.ringWidth = ColorPickerMetrics.rowRing,
    this.ringGap = ColorPickerMetrics.rowRingGap,
    this.ringColor,
  });

  /// The swatch's colour.
  final Color color;

  /// The swatch's diameter, ring included.
  final double size;

  /// The ring's thickness.
  final double ringWidth;

  /// The gap between the ring and the colour.
  final double ringGap;

  /// A solid ring colour; null draws iOS's hue-wheel ring.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: SwatchRingPainter(width: ringWidth, color: ringColor),
      child: Padding(
        padding: EdgeInsets.all(ringWidth + ringGap),
        child: ClipOval(
          child: CustomPaint(
            painter: color.a < 1 ? const CheckerboardPainter() : null,
            child: ColoredBox(color: color),
          ),
        ),
      ),
    ),
  );
}
