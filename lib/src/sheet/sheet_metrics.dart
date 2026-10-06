/// iOS 26's floating sheet at a partial detent, measured from SwiftUI's
/// `.sheet` with `.presentationDetents([.medium])` on iPhone 17 Pro / iOS
/// 26.4 (`tool/reference/controls.json`, "components" → "sheet"; tested
/// against it).
abstract final class SheetMetrics {
  /// The sheet's inset from the screen's sides and bottom.
  static const double inset = 8;

  /// The sheet's corner radius, near the screen's own.
  static const double cornerRadius = 38;

  /// The grabber.
  static const double grabberWidth = 34.67;

  /// See [grabberWidth].
  static const double grabberHeight = 5;

  /// The grabber's gap from the sheet's top edge.
  static const double grabberTop = 4.67;
}
