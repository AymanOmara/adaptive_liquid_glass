import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import 'color_picker_metrics.dart';

/// The round thumb on the spectrum square and the hue bar: the colour
/// under it inside a white ring with a soft shadow.
class SpectrumThumb extends StatelessWidget {
  /// Creates the thumb.
  const SpectrumThumb({super.key, required this.color});

  /// The colour the thumb sits on.
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: ColorPickerMetrics.thumb,
      height: ColorPickerMetrics.thumb,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: GlassColors.colorPickerThumbRing,
          width: ColorPickerMetrics.thumbRing,
        ),
        boxShadow: const [
          BoxShadow(
            color: GlassColors.thumbShadow,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
    ),
  );
}
