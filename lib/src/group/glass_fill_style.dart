/// SwiftUI's system fills (`FillShapeStyle` and its levels, lightest
/// last), and plain lighten and darken.
enum GlassFillStyle {
  /// `.fill`.
  primary,

  /// `.fill.secondary`.
  secondary,

  /// `.fill.tertiary`.
  tertiary,

  /// `.fill.quaternary`.
  quaternary,

  /// White added to the glass beneath (`.plusLighter`): lifts every
  /// channel by the same amount, keeping the backdrop's colour.
  lighten,

  /// Black subtracted from the glass beneath (`.plusDarker`): lowers every
  /// channel by the same amount, keeping the backdrop's colour.
  darken,

  /// A 1-pt white ring along the capsule, added to the glass beneath
  /// (`.plusLighter`): a brighter rim than UIKit's own.
  lightenRim,
}
