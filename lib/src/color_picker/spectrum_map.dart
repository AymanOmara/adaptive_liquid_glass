import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'color_picker_metrics.dart';
import 'spectrum_model.dart';
import 'spectrum_thumb.dart';

part 'spectrum_map_painter.dart';

/// UIColorPickerViewController's Spectrum page: one map with hue running
/// down it and white-to-hue-to-black across it (see [spectrumColorAt]),
/// and a round thumb at the colour. A tap or a drag picks the colour
/// under the finger. Like UIKit's, it is not mirrored in RTL.
class SpectrumMap extends StatelessWidget {
  /// Creates the map.
  const SpectrumMap({
    super.key,
    required this.color,
    required this.onChanged,
    this.height = ColorPickerMetrics.pageHeight,
    this.semanticLabel,
    this.hueLabel = 'Hue',
  });

  /// The colour the thumb sits on.
  final HSVColor color;

  /// Called with the colour under the finger.
  final ValueChanged<HSVColor> onChanged;

  /// The map's height; it is as wide as its parent.
  final double height;

  /// What assistive tech reads for the map.
  final String? semanticLabel;

  /// The word for hue in the map's screen-reader value.
  final String hueLabel;

  void _pick(Offset p, Size size) =>
      onChanged(spectrumColorAt(p.dx / size.width, p.dy / size.height));

  @override
  Widget build(BuildContext context) {
    final at = spectrumPositionOf(color);
    String value(double hue) => '$hueLabel ${hue.round()}°';
    HSVColor step(double by) => color.withHue((color.hue + by) % 360);
    return Semantics(
      slider: true,
      label: semanticLabel,
      value: value(color.hue),
      increasedValue: value(step(ColorPickerMetrics.hueStep).hue),
      decreasedValue: value(step(-ColorPickerMetrics.hueStep).hue),
      onIncrease: () => onChanged(step(ColorPickerMetrics.hueStep)),
      onDecrease: () => onChanged(step(-ColorPickerMetrics.hueStep)),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapDown: (d) => _pick(d.localPosition, size),
              onPanStart: (d) => _pick(d.localPosition, size),
              onPanUpdate: (d) => _pick(d.localPosition, size),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        ColorPickerMetrics.spectrumRadius,
                      ),
                      child: const CustomPaint(painter: _SpectrumMapPainter()),
                    ),
                  ),
                  Positioned(
                    left: at.dx * size.width - ColorPickerMetrics.thumb / 2,
                    top: at.dy * size.height - ColorPickerMetrics.thumb / 2,
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
}
