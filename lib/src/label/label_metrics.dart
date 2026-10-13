/// Layout of a `GlassLabel`: SwiftUI's `Label(_:systemImage:)`. Measured on
/// iOS 26.4 ("components" → "label"): at the body size the title starts
/// 30 pt after the symbol's ink (an 18.67-pt star, 11.33 pt of space);
/// the symbol keeps the body size (17 pt) and the gap makes up the rest. The Material values are Material
/// 3's button icon (18 dp) and its icon-to-label gap (8 dp).
abstract final class LabelMetrics {
  /// The icon's size, before text scaling (the body size).
  static const double iconSize = 17;

  /// The gap between the icon and the title (measured: 6 before).
  static const double iconGap = 12;

  /// The Material 3 icon size.
  static const double materialIconSize = 18;

  /// The Material 3 icon-to-label gap.
  static const double materialIconGap = 8;
}
