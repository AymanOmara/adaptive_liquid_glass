/// How a `GlassPicker` presents its choices, like SwiftUI's `PickerStyle`.
enum GlassPickerStyle {
  /// The current choice in the accent colour with an up-down chevron,
  /// opening a glass menu of the choices (`.pickerStyle(.menu)`). The
  /// default.
  menu,

  /// Every choice as a list row, the current one with a checkmark
  /// (`.pickerStyle(.inline)`). Meant to sit inside a `GlassListSection`.
  inline,

  /// One list row showing the label and the current choice with a
  /// chevron; tapping pushes a page of the choices that pops on selection
  /// (`.pickerStyle(.navigationLink)`).
  navigationLink,
}
