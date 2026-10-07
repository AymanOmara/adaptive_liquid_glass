/// Layout of a `GlassLabel`: SwiftUI's `Label(_:systemImage:)` in a list
/// row or on glass. ESTIMATED, not measured: the symbol sits at the body
/// size (17 pt) and the gap follows the measured regular glass button
/// (`GlassButtonMetrics.iconGap`, 6 pt). The Material values are Material
/// 3's button icon (18 dp) and its icon-to-label gap (8 dp).
abstract final class LabelMetrics {
  /// The icon's size, before text scaling (estimated).
  static const double iconSize = 17;

  /// The gap between the icon and the title (estimated).
  static const double iconGap = 6;

  /// The Material 3 icon size.
  static const double materialIconSize = 18;

  /// The Material 3 icon-to-label gap.
  static const double materialIconGap = 8;
}
