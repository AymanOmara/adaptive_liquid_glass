/// The date picker's wheel style, time capsule and week numbers. The band
/// is measured from SwiftUI's `.wheel` date picker (iOS 26.4,
/// "components" → "date_wheel"); its 320-pt surface and column centres
/// (month left-aligned at 69, day 220.7, year 297.8; hour 126.2, minute
/// 194.5, AM/PM 257.8) are recorded there. The day and year columns below
/// put their centres within 3 pt of those; the time columns, evenly
/// spaced, do not (UIKit packs them unevenly). The compact time capsule
/// shares the date capsule's geometry (measured within 1 pt).
abstract final class DatePickerWheelMetrics {
  /// The selection band's height (measured; the plain wheel's is 32).
  static const double bandHeight = 30.67;

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
