/// The date picker's wheel style, time capsule and week numbers. The band
/// is measured from SwiftUI's `.wheel` date picker (iOS 26.4,
/// "components" → "date_wheel"); its 320-pt surface and column centres
/// (month left-aligned at 69, day 220.7, year 297.8) are recorded there;
/// the day and year columns below put their centres within 3 pt of those.
/// The time styles copy UIKit's uneven packing (`-controls datewheel` and
/// `timewheel`, "date_wheel" → "time_columns"): each keeps the 320-pt
/// surface, its hours and dates end at a fixed line and its minutes and
/// AM/PM start at one, given below from the surface's leading edge. The
/// compact time capsule shares the date capsule's geometry (measured
/// within 1 pt).
abstract final class DatePickerWheelMetrics {
  /// The selection band's height (measured; the plain wheel's is 32).
  static const double bandHeight = 30.67;

  /// The day column's width (estimated).
  static const double dayWidth = 64;

  /// The month column's width (estimated; fits "September").
  static const double monthWidth = 132;

  /// The year column's width (estimated).
  static const double yearWidth = 88;

  /// The 12-hour time wheel's hours end here (measured; hours align to
  /// the end).
  static const double time12HourEnd = 97.33;

  /// The 12-hour time wheel's minutes start here (measured).
  static const double time12MinuteStart = 142;

  /// The 12-hour time wheel's AM/PM starts here (measured: AM's ink;
  /// UIKit centres AM and PM on 216.8, within 1.5 pt of both starting
  /// here).
  static const double time12PeriodStart = 200.67;

  /// The 24-hour time wheel's hours end here (measured, en_GB).
  static const double time24HourEnd = 130.33;

  /// The 24-hour time wheel's minutes start here (measured, en_GB).
  static const double time24MinuteStart = 179;

  /// The date-and-time wheel's dates end here (measured).
  static const double dateTimeDateEnd = 138;

  /// The date-and-time wheel's hours end here (measured).
  static const double dateTimeHourEnd = 179.33;

  /// The date-and-time wheel's minutes start here (measured).
  static const double dateTimeMinuteStart = 214;

  /// The date-and-time wheel's AM/PM starts here (measured).
  static const double dateTimePeriodStart = 265.67;

  /// The room a time column keeps between its label and the next column,
  /// where their drag areas meet.
  static const double timeColumnGap = 4;

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
