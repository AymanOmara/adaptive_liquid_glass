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

  /// The opacity of the blue band joining a range's days (estimated).
  static const double rangeAlpha = 0.18;

  /// A day's size.
  static const double dayFontSize = 20;

  /// The weekday labels' size (semibold, upper case).
  static const double weekdayFontSize = 13;

  /// The month header's size (semibold).
  static const double headerFontSize = 17;

  /// The inline (`.graphical`) calendar's inset above its header
  /// (measured, `-controls calendargraphicaltime`: the inline calendar
  /// fills its width, header 16 pt below its top).
  static const double inlineTop = 16;

  /// The inline calendar's header height (measured: the month button and
  /// the arrows are 37.67 pt tall).
  static const double inlineHeaderHeight = 37.67;

  /// The inset of the inline header's month label and of the arrows' ink
  /// from the calendar's sides (measured: 8 at both ends).
  static const double inlineInset = 8;

  /// An inline month arrow's tap width (measured: two adjacent 43.33-pt
  /// buttons, each chevron centred).
  static const double inlineArrowWidth = 43.33;

  /// The gap between the inline header and the weekday row (measured).
  static const double inlineWeekdayGap = 16;

  /// The inline weekday row's height (measured).
  static const double inlineWeekdayHeight = 17.67;

  /// The distance between week rows in the inline calendar (measured: 44
  /// at width 370; the columns split the full width in seven).
  static const double inlineRow = 44;

  /// The inline calendar's day circle (measured: 44).
  static const double inlineSelection = 44;

  /// The opacity of the tinted circle behind a selected day that is not
  /// today (measured: system blue at 12%, the number in blue; today, when
  /// selected, takes the solid circle and white number).
  static const double selectedTintAlpha = 0.12;

  /// The inset of `showGlassDatePicker`'s sheet header and content from
  /// the sheet's edges (estimated).
  static const double sheetPadding = 16;
}
