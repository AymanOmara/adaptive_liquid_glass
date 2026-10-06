/// iOS 26's page control's geometry. Values are ESTIMATED from UIKit's
/// `UIPageControl` and the HIG defaults on iOS 26, not measured.
abstract final class PageControlMetrics {
  /// A dot's diameter.
  static const double dotSize = 8;

  /// The gap between neighbouring dots.
  static const double dotSpacing = 9;

  /// The capsule's height.
  static const double height = 26;

  /// The capsule's inset before the first and after the last dot.
  static const double horizontalPadding = 11;

  /// The alpha of the dots that are not the current page.
  static const double inactiveOpacity = 0.3;

  /// A Material dot's diameter.
  static const double materialDotSize = 8;

  /// The Material current dot's width (a pill).
  static const double materialActiveWidth = 20;

  /// The gap between Material dots, as padding on each side of a dot.
  static const double materialSpacing = 6;

  /// The alpha of the Material dots that are not the current page.
  static const double materialInactiveOpacity = 0.38;

  /// How long moving to a picked page takes.
  static const Duration pageAnimation = Duration(milliseconds: 300);

  /// How long a dot's fade takes.
  static const Duration dotAnimation = Duration(milliseconds: 200);
}
