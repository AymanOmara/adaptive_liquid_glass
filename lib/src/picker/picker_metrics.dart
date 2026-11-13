/// The picker's geometry. Values say whether they were measured from
/// SwiftUI (iOS 26.4) or estimated; the inline and navigation-link rows
/// take their geometry from `ListMetrics`.
abstract final class PickerMetrics {
  /// The menu picker's label size (measured: 17 pt).
  static const double fontSize = 17;

  /// The menu picker's up-down chevron size (estimated).
  static const double chevronSize = 13;

  /// The gap between the menu picker's label and its chevron (estimated).
  static const double chevronGap = 4;

  /// The menu picker's vertical inset (estimated).
  static const double verticalPadding = 8;

  /// The inline picker's checkmark size (estimated: SF Symbols'
  /// `checkmark` at body size).
  static const double checkSize = 17;

  /// A palette picker's swatch inside a `Menu` (measured, iOS 26.4: a
  /// 17-pt `circle.fill`). Kept for the in-menu palette row.
  static const double paletteSwatchSize = 17;

  /// The pitch between a menu palette's swatches (measured: 42.6 pt).
  static const double paletteSwatchPitch = 42.6;

  /// The rounded square behind a menu palette's selected swatch
  /// (measured: 37.5 pt; its corner radius estimated at 8).
  static const double paletteSelectionSize = 37.5;
}
