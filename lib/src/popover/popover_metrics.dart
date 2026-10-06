/// iOS 26's popover, measured from SwiftUI's `.popover` (kept a popover on
/// iPhone with `.presentationCompactAdaptation(.popover)`) and the compact
/// date picker's calendar on iPhone 17 Pro / iOS 26.4. It opens over its
/// anchor rather than beside it, without an arrow.
abstract final class PopoverMetrics {
  /// The bubble's corner radius (a one-line popover is 52 pt tall).
  static const double cornerRadius = 26;

  /// The bubble's own padding above and below its content (measured: 16
  /// pt of content padding makes a 68-pt bubble for 17-pt text).
  static const double verticalInset = 8;

  /// The closest the bubble comes to the screen's edges.
  static const double margin = 10;

  /// The bubble's top below its anchor's top (measured from a toolbar
  /// button).
  static const double overlap = 10;

  /// The date picker's calendar: its top below the capsule's top
  /// (measured).
  static const double calendarOverlap = 24;
}
