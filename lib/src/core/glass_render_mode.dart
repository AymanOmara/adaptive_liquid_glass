/// How a glass widget is rendered.
enum GlassRenderMode {
  /// Pick per platform: shader on iOS (native on iOS 26+ when enabled in the
  /// theme), Material 3 elsewhere.
  auto,

  /// Flutter fragment shader glass.
  shader,

  /// Apple's own UIKit glass view (iOS 26+; falls back to [shader]).
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

  /// Apple's own UIKit glass view.
  native,

  /// Material 3 surface.
  material,

  /// Opaque surface for reduced transparency.
  opaque,
}
