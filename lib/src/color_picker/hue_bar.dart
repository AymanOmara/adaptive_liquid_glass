import 'package:flutter/widgets.dart';

import 'color_picker_metrics.dart';
import 'spectrum_thumb.dart';

/// The hue bar of a colour picker: the full hue sweep in a rounded bar,
/// red at both ends, with a round thumb at the hue. Like the spectrum,
/// it is not mirrored in RTL.
class HueBar extends StatelessWidget {
  /// Creates the bar.
  const HueBar({
    super.key,
    required this.color,
    required this.onChanged,
    this.semanticLabel,
  });

  /// The colour whose hue places the thumb.
  final HSVColor color;

  /// Called as the thumb is dragged or the bar tapped.
  final ValueChanged<HSVColor> onChanged;

  /// What assistive tech reads for the bar.
  final String? semanticLabel;

  static const _stops = 7;

  void _pick(double dx, double width) =>
      onChanged(color.withHue((dx / width).clamp(0.0, 1.0) * 360 % 360));

  @override
  Widget build(BuildContext context) {
    final hue = color.hue;
    String label(double h) => 'Hue ${h.round()}°';
    return Semantics(
      slider: true,
      label: semanticLabel,
      value: label(hue),
      increasedValue: label((hue + ColorPickerMetrics.hueStep) % 360),
      decreasedValue: label((hue - ColorPickerMetrics.hueStep) % 360),
      onIncrease: () =>
          onChanged(color.withHue((hue + ColorPickerMetrics.hueStep) % 360)),
      onDecrease: () =>
          onChanged(color.withHue((hue - ColorPickerMetrics.hueStep) % 360)),
      child: SizedBox(
        height: ColorPickerMetrics.hueBarHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTapDown: (d) => _pick(d.localPosition.dx, width),
              onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, width),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          ColorPickerMetrics.spectrumRadius,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            for (var i = 0; i < _stops; i++)
                              HSVColor.fromAHSV(
                                1,
                                i * 360 / (_stops - 1) % 360,
                                1,
                                1,
                              ).toColor(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: hue / 360 * width - ColorPickerMetrics.thumb / 2,
                    top:
                        (ColorPickerMetrics.hueBarHeight -
                            ColorPickerMetrics.thumb) /
                        2,
                    child: SpectrumThumb(
                      color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                    ),
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
