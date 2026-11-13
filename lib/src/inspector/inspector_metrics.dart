/// iOS 26's `.inspector` geometry. The breakpoint is the package's
/// regular-width one; the column width and timing are ESTIMATED from
/// SwiftUI's defaults, not measured.
abstract final class InspectorMetrics {
  /// The narrowest width that shows the inspector as a trailing column;
  /// narrower shows it as a sheet (SwiftUI's regular vs compact width).
  static const double regularWidth = 700;

  /// The trailing column's width (SwiftUI's default inspector width).
  static const double columnWidth = 320;

  /// The separator between the content and the column.
  static const double separatorWidth = 0.5;

  /// How long the column takes to slide in or out.
  static const Duration columnAnimation = Duration(milliseconds: 350);
}
