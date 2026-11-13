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
  /// 17-pt `circle.fill`).
  static const double paletteSwatchSize = 17;

  /// The pitch between a menu palette's swatches (measured, iOS 26.4:
  /// 42.67 pt, five swatches centred in the 252-pt menu).
  static const double paletteSwatchPitch = 42.67;

  /// The rounded square behind a menu palette's selected swatch
  /// (measured: about 37.5 pt; its corner radius estimated at 8).
  static const double paletteSelectionSize = 37.5;

  /// The selection square's corner radius (estimated).
  static const double paletteSelectionRadius = 8;

  /// A menu palette row's height (measured, iOS 26.4: the swatch centres
  /// 16.17 pt under the section title's block, and the next section's
  /// divider follows 16.17 pt under them).
  static const double paletteRowHeight = 32.33;
}
