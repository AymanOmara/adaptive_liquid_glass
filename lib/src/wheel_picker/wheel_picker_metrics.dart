/// iOS 26's wheel picker, after SwiftUI's `Picker` with
/// `.pickerStyle(.wheel)` and Flutter's `CupertinoPicker` defaults.
abstract final class WheelPickerMetrics {
  /// A row's height (iOS's default).
  static const double itemExtent = 32;

  /// The wheel's height (iOS's default, about 6.75 rows).
  static const double height = 216;

  /// The wheel's width when the parent sets none (UIPickerView's default).
  static const double width = 320;

  /// A label's size.
  static const double fontSize = 21;

  /// A row's padding either side of its label.
  static const double rowPadding = 16;

  /// The surface's corner radius.
  static const double surfaceRadius = 12;

  /// The selection band's corner radius.
  static const double bandRadius = 8;

  /// The selection band's inset from the surface's sides.
  static const double bandInset = 9;

  /// The cylinder's diameter as a ratio of the viewport (iOS's curvature).
  static const double diameterRatio = 1.07;

  /// How tightly rows pack as they bend away (iOS's).
  static const double squeeze = 1.45;

  /// The perspective of rows off the centre (iOS's).
  static const double perspective = 0.003;

  /// Rows off the centre fade to this opacity (iOS's).
  static const double offCenterOpacity = 0.447;

  /// How long a programmatic step takes.
  static const Duration stepDuration = Duration(milliseconds: 200);
}
