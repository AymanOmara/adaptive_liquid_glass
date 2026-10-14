import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'color_picker_metrics.dart';

/// The eyedropper's loupe: the captured pixels around [pixel], magnified
/// with hard edges, the centre pixel outlined, in a ring of the colour
/// under it.
class EyedropperLoupe extends StatelessWidget {
  /// Creates the loupe.
  const EyedropperLoupe({
    super.key,
    required this.image,
    required this.pixel,
    required this.color,
  });

  /// The captured app.
  final ui.Image image;

  /// The sampled point, in [image]'s pixels.
  final Offset pixel;

  /// The colour under [pixel].
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      size: const Size.square(ColorPickerMetrics.loupe),
      painter: _LoupePainter(image, pixel, color),
    ),
  );
}

class _LoupePainter extends CustomPainter {
  const _LoupePainter(this.image, this.pixel, this.color);

  final ui.Image image;
  final Offset pixel;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    const cells = ColorPickerMetrics.loupeCells;
    final cell = size.width / cells;
    final px = Offset(pixel.dx.floorToDouble(), pixel.dy.floorToDouble());
    final source = Rect.fromLTWH(
      px.dx - (cells - 1) / 2,
      px.dy - (cells - 1) / 2,
      cells.toDouble(),
      cells.toDouble(),
    );
    final circle = Path()..addOval(rect);
    canvas
      ..save()
      ..clipPath(circle)
      ..drawRect(rect, Paint()..color = GlassColors.white)
      ..drawImageRect(
        image,
        source,
        rect,
        Paint()..filterQuality = FilterQuality.none,
      )
      ..restore()
      ..drawRect(
        Rect.fromCenter(center: centre, width: cell, height: cell),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = GlassColors.white,
      )
      ..drawCircle(
        centre,
        size.width / 2 - ColorPickerMetrics.loupeRing / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ColorPickerMetrics.loupeRing
          ..color = color,
      )
      ..drawCircle(
        centre,
        size.width / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = GlassColors.white,
      );
  }

  @override
  bool shouldRepaint(_LoupePainter old) =>
      old.image != image || old.pixel != pixel || old.color != color;
}
