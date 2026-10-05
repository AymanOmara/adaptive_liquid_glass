/// How a glass widget is rendered.
enum GlassRenderMode {
  /// Pick per platform: SwiftUI's own glass on iOS 26+, the shader on
  /// older iOS, Material 3 elsewhere.
  auto,

  /// Flutter fragment shader glass.
  shader,

  /// SwiftUI's own Liquid Glass in a platform view (iOS 26+; falls back to
  /// [shader]).
  native,

  /// A Material 3 surface.
  material,
}

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
