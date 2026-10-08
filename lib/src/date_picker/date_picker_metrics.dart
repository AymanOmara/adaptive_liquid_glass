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

/// The date picker's wheel style, time capsule and week numbers. Estimated
/// from iOS 26's `.wheel` date picker and compact time capsule, not
/// measured.
abstract final class DatePickerWheelMetrics {
  /// The day column's width (estimated).
  static const double dayWidth = 64;

  /// The month column's width (estimated; fits "September").
  static const double monthWidth = 132;

  /// The year column's width (estimated).
  static const double yearWidth = 88;

  /// The combined weekday-and-date column's width in date-and-time mode
  /// (estimated; fits "Wed Sep 30").
  static const double dateTimeWidth = 150;

  /// The hour, minute and AM/PM columns' width (estimated).
  static const double timeColumnWidth = 60;

  /// The gap between the date and time capsules in date-and-time mode
  /// (estimated).
  static const double capsuleGap = 8;

  /// The gap between an inline calendar and the time row under it
  /// (estimated).
  static const double timeRowGap = 8;

  /// The week-number column's width in a calendar showing them
  /// (estimated).
  static const double weekNumberWidth = 28;

  /// The inset of the time wheel inside its popover (estimated).
  static const double popoverPadding = 8;
}
