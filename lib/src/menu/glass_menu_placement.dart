/// Where a glass menu opens relative to what opened it.
enum GlassMenuPlacement {
  /// Over the button, from its top corner on the nearer side (its bottom
  /// corner near the screen's bottom), as SwiftUI's `Menu`.
  corner,

  /// Centred on it, the first row just below its centre, as SwiftUI's
  /// menu-style `Picker`.
  centred,
}
