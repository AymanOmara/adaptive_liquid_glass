/// Which parts of a [DateTime] a `GlassDatePicker` edits, after SwiftUI's
/// `DatePickerComponents`.
///
/// ```dart
/// GlassDatePicker(
///   pickerMode: GlassDatePickerMode.time,
///   value: when,
///   firstDate: DateTime(2020),
///   lastDate: DateTime(2030),
///   onChanged: (d) => setState(() => when = d),
/// )
/// ```
enum GlassDatePickerMode {
  /// The day, month and year (`.date`). The default.
  date,

  /// The hour and minute (`.hourAndMinute`); the day is kept.
  time,

  /// Both (`[.date, .hourAndMinute]`).
  dateAndTime,
}
