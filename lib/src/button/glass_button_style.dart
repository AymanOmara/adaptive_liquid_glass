/// SwiftUI's button styles: iOS 26's glass styles and the system styles
/// drawn without glass.
enum GlassButtonStyle {
  /// `.glass`: plain interactive glass with a readable label.
  glass,

  /// `.glassProminent`: glass tinted with the accent, white label.
  glassProminent,

  /// `.bordered`: no glass; a grey fill (the tint at low opacity when one
  /// is given, red for a destructive role) behind an accent label.
  bordered,

  /// `.borderedProminent`: no glass; a solid accent fill, white label.
  borderedProminent,

  /// `.borderless`: no background or padding; the label in the accent
  /// colour, dimmed while pressed.
  borderless,

  /// `.plain`: no background or padding; the label in the primary label
  /// colour, dimmed while pressed.
  plain,
}
