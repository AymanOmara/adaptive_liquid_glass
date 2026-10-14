/// iOS 26's compact date picker and its calendar, measured from SwiftUI's
/// `DatePicker` (`.compact`, date only) on iPhone 17 Pro / iOS 26.4.
abstract final class DatePickerMetrics {
  /// The capsule's height.
  static const double height = 36.33;

  /// The capsule's padding either side of the date.
  static const double padding = 13;

  /// The date's size.
  static const double fontSize = 17;

  /// The calendar's width.
  static const double calendarWidth = 320;

  /// The calendar's padding.
  static const double calendarPadding = 20;

  /// The distance between day columns.
  static const double column = 42.7;

  /// The distance between week rows.
  static const double row = 38;

  /// The selected day's circle.
  static const double selection = 38;

  /// A day's size.
  static const double dayFontSize = 20;

  /// The weekday labels' size (semibold, upper case).
  static const double weekdayFontSize = 13;

  /// The month header's size (semibold).
  static const double headerFontSize = 17;
}
