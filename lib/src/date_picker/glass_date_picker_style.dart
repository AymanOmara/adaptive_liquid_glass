/// How a `GlassDatePicker` lays itself out, after SwiftUI's
/// `DatePickerStyle`.
///
/// ```dart
/// GlassDatePicker(
///   style: GlassDatePickerStyle.graphical,
///   value: date,
///   firstDate: DateTime(2020),
///   lastDate: DateTime(2030),
///   onChanged: (d) => setState(() => date = d),
/// )
/// ```
enum GlassDatePickerStyle {
  /// The value in a grey capsule opening a popover (`.compact`). The
  /// default.
  compact,

  /// The calendar inline, a time capsule below it when the mode has a
  /// time (`.graphical`).
  graphical,

  /// Wheel columns on one glass surface (`.wheel`).
  wheel,
}
