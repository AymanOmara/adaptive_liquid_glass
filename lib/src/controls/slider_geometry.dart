import 'package:flutter/widgets.dart';

import 'control_metrics.dart';

/// Where a slider's thumbs sit along a track [length] long, and which
/// fraction a touch is at: shared by `GlassSlider` and `GlassRangeSlider`.
///
/// Fractions grow from the reading direction's start when [axis] is
/// horizontal, and from the bottom when vertical.
@immutable
class SliderGeometry {
  /// Creates the geometry.
  const SliderGeometry({
    required this.axis,
    required this.length,
    required this.rtl,
  });

  /// The track's direction.
  final Axis axis;

  /// The track's length along [axis].
  final double length;

  /// Whether a horizontal track reads right to left.
  final bool rtl;

  /// How far a thumb's centre travels from 0 to 1.
  double get travel {
    final t = length - ControlMetrics.sliderThumbWidth;
    return t < 0 ? 0 : t;
  }

  /// The thumb's centre at [fraction], from the track's start.
  double centre(double fraction) =>
      ControlMetrics.sliderThumbWidth / 2 + fraction * travel;

  /// The (unclamped) fraction at a touch [local] to the slider.
  double fractionAt(Offset local) {
    final along = axis == Axis.vertical
        ? length - local.dy
        : rtl
        ? length - local.dx
        : local.dx;
    return travel <= 0
        ? 0
        : (along - ControlMetrics.sliderThumbWidth / 2) / travel;
  }
}
