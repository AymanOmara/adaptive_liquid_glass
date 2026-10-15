import 'effective_glass_mode.dart';

/// The rendering path a glass widget actually takes once its
/// `GlassRenderMode` is resolved for the device and its settings; see
/// `GlassAdaptive.pathOf`.
enum GlassEffectivePath {
  /// SwiftUI's own Liquid Glass (iOS 26 and later).
  native,

  /// Flutter fragment shader glass.
  shader,

  /// Frosted blur, where the shader is unsupported.
  degraded,

  /// An opaque surface, for Reduce Transparency or high contrast.
  opaque,

  /// A Material 3 surface.
  material;

  /// Whether this is a glass path: every path but [material].
  bool get isGlass => this != material;
}

/// The public form of the resolver's [mode]. Internal.
GlassEffectivePath glassEffectivePathOf(EffectiveGlassMode mode) =>
    switch (mode) {
      EffectiveGlassMode.native => GlassEffectivePath.native,
      EffectiveGlassMode.shader => GlassEffectivePath.shader,
      EffectiveGlassMode.degraded => GlassEffectivePath.degraded,
      EffectiveGlassMode.opaque => GlassEffectivePath.opaque,
      EffectiveGlassMode.material => GlassEffectivePath.material,
    };
