import 'package:flutter/rendering.dart';

import '../core/glass_colors.dart';
import 'color_picker_metrics.dart';

/// The light and dark checkerboard shown under a translucent colour.
class CheckerboardPainter extends CustomPainter {
  /// Creates the painter.
  const CheckerboardPainter({this.cell = ColorPickerMetrics.checker});

  /// A cell's side.
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    // The other cells stay clear: UIKit's show the sheet through them.
    final dark = Paint()..color = GlassColors.colorPickerChecker;
    final columns = (size.width / cell).ceil();
    final rows = (size.height / cell).ceil();
    for (var y = 0; y < rows; y++) {
      for (var x = y & 1; x < columns; x += 2) {
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), dark);
      }
    }
  }

  @override
  bool shouldRepaint(CheckerboardPainter oldDelegate) =>
      oldDelegate.cell != cell;
}
