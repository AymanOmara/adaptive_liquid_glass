/// Where iOS 26 floats its tab bar and its bottom accessory, measured from
/// SwiftUI on iPhone 17 Pro / iOS 26.4 (`tool/reference/controls.json`,
/// "components" → "accessory"; tested against it).
abstract final class ScaffoldMetrics {
  /// The tab bar's bottom edge above the screen's on a phone with a home
  /// indicator (Kept: 21 over a 34 safe area).
  static const double tabBarBottom = 21;

  /// The same gap on a screen without a home indicator.
  static const double tabBarBottomFlat = 8;

  /// The gap between the bottom accessory and the tab bar.
  static const double accessoryGap = 8;

  /// The bottom accessory's height.
  static const double accessoryHeight = 48;

  /// The bottom accessory's inset from the screen's sides.
  static const double accessoryInset = 21;
}
