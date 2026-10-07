import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'checkerboard_painter.dart';
import 'color_picker_metrics.dart';

/// A round colour swatch with a thin ring, like the one at the end of
/// iOS's `ColorPicker` row. A translucent colour shows a checkerboard
/// through it.
class ColorSwatchDot extends StatelessWidget {
  /// Creates a swatch.
  const ColorSwatchDot({
    super.key,
    required this.color,
    this.size = ColorPickerMetrics.rowSwatch,
    this.ringWidth = ColorPickerMetrics.rowRing,
    this.ringColor,
  });

  /// The swatch's colour.
  final Color color;

  /// The swatch's diameter.
  final double size;

  /// The ring's thickness.
  final double ringWidth;

  /// The ring's colour; defaults to [GlassColors.colorPickerRing].
  final Color? ringColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: ClipOval(
      child: CustomPaint(
        painter: color.a < 1 ? const CheckerboardPainter() : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: ringColor ?? GlassColors.colorPickerRing,
              width: ringWidth,
            ),
          ),
        ),
      ),
    ),
  );
}
