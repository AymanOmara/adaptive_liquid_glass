import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'color_picker_metrics.dart';
import 'spectrum_thumb.dart';

/// The saturation-value square of a colour picker: the hue fades to white
/// toward the left and to black toward the bottom, with a round thumb at
/// the colour. Like the spectrum, it is not mirrored in RTL.
class HsvSpectrum extends StatelessWidget {
  /// Creates the square.
  const HsvSpectrum({
    super.key,
    required this.color,
    required this.onChanged,
    this.height = ColorPickerMetrics.spectrumHeight,
    this.semanticLabel,
  });

  /// The colour; its hue fills the square, its saturation and value place
  /// the thumb.
  final HSVColor color;

  /// Called as the thumb is dragged or the square tapped.
  final ValueChanged<HSVColor> onChanged;

  /// The square's height; it is as wide as its parent.
  final double height;

  /// What assistive tech reads for the square.
  final String? semanticLabel;

  void _pick(Offset position, Size size) {
    final s = (position.dx / size.width).clamp(0.0, 1.0);
    final v = 1 - (position.dy / size.height).clamp(0.0, 1.0);
    onChanged(color.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    value:
        'Saturation ${(color.saturation * 100).round()}%, '
        'brightness ${(color.value * 100).round()}%',
    child: SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _pick(d.localPosition, size),
            onPanUpdate: (d) => _pick(d.localPosition, size),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      ColorPickerMetrics.spectrumRadius,
                    ),
                    child: CustomPaint(painter: _SpectrumPainter(color.hue)),
                  ),
                ),
                Positioned(
                  left:
                      color.saturation * size.width -
                      ColorPickerMetrics.thumb / 2,
                  top:
                      (1 - color.value) * size.height -
                      ColorPickerMetrics.thumb / 2,
                  child: SpectrumThumb(color: color.toColor()),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _SpectrumPainter extends CustomPainter {
  const _SpectrumPainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            GlassColors.white,
            HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GlassColors.transparent, GlassColors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SpectrumPainter oldDelegate) => oldDelegate.hue != hue;
}
