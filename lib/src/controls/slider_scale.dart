import 'package:flutter/foundation.dart' show immutable;

/// A slider's values between [min] and [max] as fractions of its track,
/// snapped to [divisions]: shared by `GlassSlider` and `GlassRangeSlider`.
@immutable
class SliderScale {
  /// Creates the scale.
  const SliderScale({required this.min, required this.max, this.divisions});

  /// The least value.
  final double min;

  /// The greatest value.
  final double max;

  /// The number of steps between [min] and [max]; null is continuous.
  final int? divisions;

  /// How far assistive tech moves the value: one division, or a tenth.
  double get step => divisions == null ? 0.1 : 1 / divisions!;

  /// [value]'s fraction of the track, 0 to 1.
  double fractionOf(double value) =>
      ((value - min) / (max - min)).clamp(0.0, 1.0);

  /// The value at [fraction], clamped and snapped to [divisions].
  double valueAt(double fraction) =>
      min + _snap(fraction.clamp(0.0, 1.0)) * (max - min);

  /// [value] as a percentage of the range, as iOS reads a slider.
  String percent(double value) =>
      '${((value - min) / (max - min) * 100).round()}%';

  double _snap(double fraction) {
    final divisions = this.divisions;
    if (divisions == null) return fraction;
    return (fraction * divisions).round() / divisions;
  }
}
