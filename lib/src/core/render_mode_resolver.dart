import 'package:flutter/foundation.dart';

import 'effective_glass_mode.dart';
import 'glass_environment.dart';
import 'glass_render_mode.dart';

/// Resolves the rendering path. Order is spec §5 as amended in §14.2,
/// with native glass the default on iOS 26+ (Task N1).
///
/// `auto` is SwiftUI's own glass on iOS 26 and later, the shader below
/// (degraded without shader support) and Material elsewhere. Reduce
/// Transparency makes the Flutter-drawn paths opaque; native glass handles
/// the system setting itself, as SwiftUI does, but is drawn opaque too when
/// the app forces the setting on (SwiftUI cannot see that).
EffectiveGlassMode resolveGlassMode({
  required GlassRenderMode requested,
  required GlassEnvironment environment,
}) {
  final isIOS = environment.platform == TargetPlatform.iOS;
  final nativeAvailable = isIOS && (environment.iosMajorVersion ?? 0) >= 26;
  final shaderPath = environment.shaderSupported
      ? EffectiveGlassMode.shader
      : EffectiveGlassMode.degraded;

  final EffectiveGlassMode mode = switch (requested) {
    GlassRenderMode.material => EffectiveGlassMode.material,
    GlassRenderMode.shader => shaderPath,
    GlassRenderMode.native =>
      nativeAvailable ? EffectiveGlassMode.native : shaderPath,
    GlassRenderMode.auto =>
      !isIOS
          ? EffectiveGlassMode.material
          : nativeAvailable
          ? EffectiveGlassMode.native
          : shaderPath,
  };

  if (environment.reduceTransparency &&
      (mode == EffectiveGlassMode.shader ||
          mode == EffectiveGlassMode.degraded ||
          (mode == EffectiveGlassMode.native &&
              environment.reduceTransparencyForced))) {
    return EffectiveGlassMode.opaque;
  }
  return mode;
}
