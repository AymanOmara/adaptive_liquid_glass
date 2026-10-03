import 'package:flutter/foundation.dart';

import 'glass_environment.dart';
import 'glass_render_mode.dart';

/// Resolves the rendering path. Order is spec §5 as amended in §14.2.
EffectiveGlassMode resolveGlassMode({
  required GlassRenderMode requested,
  required bool nativeEnabled,
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
    GlassRenderMode.auto => !isIOS
        ? EffectiveGlassMode.material
        : (nativeEnabled && nativeAvailable)
            ? EffectiveGlassMode.native
            : shaderPath,
  };

  if (environment.reduceTransparency &&
      (mode == EffectiveGlassMode.shader ||
          mode == EffectiveGlassMode.degraded)) {
    return EffectiveGlassMode.opaque;
  }
  return mode;
}
