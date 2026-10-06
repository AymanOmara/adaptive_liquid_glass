/// iOS 26's floating sheet. Approximate: read from iOS 26.4 screenshots,
/// not yet fitted against SwiftUI scenes.
abstract final class SheetMetrics {
  /// The sheet's inset from the screen's sides and bottom.
  static const double inset = 8;

  /// The sheet's corner radius, near the screen's own.
  static const double cornerRadius = 38;

  /// The grabber.
  static const double grabberWidth = 36;

  /// See [grabberWidth].
  static const double grabberHeight = 5;

  /// The grabber's gap from the sheet's top edge.
  static const double grabberTop = 5;
}
