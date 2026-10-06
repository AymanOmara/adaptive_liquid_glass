/// The rendering path actually used after resolution. Internal.
enum EffectiveGlassMode {
  /// Flutter fragment shader glass.
  shader,

  /// Shader unsupported; degrade gracefully.
  degraded,

  /// SwiftUI's own Liquid Glass in a platform view.
  native,

  /// Material 3 surface.
  material,

  /// Opaque surface for reduced transparency.
  opaque,
}
