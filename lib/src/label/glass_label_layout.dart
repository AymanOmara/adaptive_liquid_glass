/// Which parts of a `GlassLabel` show, like SwiftUI's `labelStyle`.
enum GlassLabelLayout {
  /// The icon at the start, the title after it (`.titleAndIcon`).
  titleAndIcon,

  /// Only the icon; the title still names it for assistive tech
  /// (`.iconOnly`).
  iconOnly,

  /// Only the title (`.titleOnly`).
  titleOnly,
}
