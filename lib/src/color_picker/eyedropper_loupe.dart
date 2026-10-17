import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'color_picker_metrics.dart';

/// The eyedropper's loupe, as UIColorPickerViewController's (measured on
/// iOS 26.4): a disk of the colour under [pixel] around a ring, inside it
/// the captured pixels magnified one cell per pixel on a grid, the centre
/// cell outlined. Ring, grid and outline are grey over a light colour and
/// white over a darker one.
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
    final centre = (Offset.zero & size).center;
    const cell = ColorPickerMetrics.loupeCell;
    const cells = ColorPickerMetrics.loupeCells;
    const ring = ColorPickerMetrics.loupeRing;
    const ringRadius = ColorPickerMetrics.loupeRingRadius;
    final light =
        color.computeLuminance() >= ColorPickerMetrics.loupeLightLuminance;
    final mark = light
        ? GlassColors.colorPickerLoupeRingOnLight
        : GlassColors.white;
    final px = Offset(pixel.dx.floorToDouble(), pixel.dy.floorToDouble());
    final source = Rect.fromLTWH(
      px.dx - (cells - 1) / 2,
      px.dy - (cells - 1) / 2,
      cells.toDouble(),
      cells.toDouble(),
    );
    final grid = Rect.fromCenter(
      center: centre,
      width: cells * cell,
      height: cells * cell,
    );
    canvas
      ..drawCircle(
        centre.translate(0, ColorPickerMetrics.loupeShadowDrop),
        size.width / 2,
        Paint()
          ..color = GlassColors.colorPickerLoupeShade
          ..maskFilter = const MaskFilter.blur(
            BlurStyle.normal,
            ColorPickerMetrics.loupeShadowSigma,
          ),
      )
      ..drawCircle(centre, size.width / 2, Paint()..color = color)
      ..save()
      ..clipPath(
        Path()..addOval(Rect.fromCircle(center: centre, radius: ringRadius)),
      )
      ..drawImageRect(
        image,
        source,
        grid,
        Paint()..filterQuality = FilterQuality.none,
      );
    final line = Paint()
      ..strokeWidth = ColorPickerMetrics.loupeGridLine
      ..color = light
          ? GlassColors.colorPickerLoupeGridOnLight
          : GlassColors.colorPickerLoupeGridOnDark;
    for (var i = 1; i < cells; i++) {
      final x = grid.left + i * cell;
      final y = grid.top + i * cell;
      canvas
        ..drawLine(Offset(x, grid.top), Offset(x, grid.bottom), line)
        ..drawLine(Offset(grid.left, y), Offset(grid.right, y), line);
    }
    canvas
      ..restore()
      ..drawRect(
        Rect.fromCenter(center: centre, width: cell, height: cell),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ColorPickerMetrics.loupeOutline
          ..strokeJoin = StrokeJoin.round
          ..color = mark,
      )
      ..drawCircle(
        centre,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring
          ..color = mark,
      );
  }

  @override
  bool shouldRepaint(_LoupePainter old) =>
      old.image != image || old.pixel != pixel || old.color != color;
}
