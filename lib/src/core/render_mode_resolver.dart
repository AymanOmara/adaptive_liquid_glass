import 'package:flutter/foundation.dart';

import 'effective_glass_mode.dart';
import 'glass_environment.dart';
import 'glass_render_mode.dart';

/// Resolves the rendering path. Order is spec §5 as amended in §14.2,
/// with native glass the default on iOS 26+ (Task N1).
///
/// `auto` is SwiftUI's own glass on iOS 26 and later, the shader below
/// (degraded without shader support) and Material elsewhere, except on
/// Android with [supportLiquidGlassOnAndroid]
/// (`LiquidGlassThemeData.supportLiquidGlassOnAndroid`), where it is the
/// shader (degraded without shader support). Other platforms ignore the
/// flag. Reduce
/// Transparency makes the Flutter-drawn paths opaque; native glass handles
/// the system setting itself, as SwiftUI does, but is drawn opaque too when
/// the app forces the setting on (SwiftUI cannot see that). High contrast
/// ([highContrast], `MediaQuery.highContrastOf`) makes the Flutter-drawn
/// paths opaque too, so text keeps its contrast; SwiftUI's glass follows
/// Increase Contrast itself.
EffectiveGlassMode resolveGlassMode({
  required GlassRenderMode requested,
  required GlassEnvironment environment,
  required bool highContrast,
  bool supportLiquidGlassOnAndroid = false,
}) {
  final isIOS = environment.platform == TargetPlatform.iOS;
  final androidGlass =
      supportLiquidGlassOnAndroid &&
      environment.platform == TargetPlatform.android;
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
      androidGlass
          ? shaderPath
          : !isIOS
          ? EffectiveGlassMode.material
          : nativeAvailable
          ? EffectiveGlassMode.native
          : shaderPath,
  };

  final flutterDrawn =
      mode == EffectiveGlassMode.shader || mode == EffectiveGlassMode.degraded;
  if (highContrast && flutterDrawn) return EffectiveGlassMode.opaque;
  if (environment.reduceTransparency &&
      (flutterDrawn ||
          (mode == EffectiveGlassMode.native &&
              environment.reduceTransparencyForced))) {
    return EffectiveGlassMode.opaque;
  }
  return mode;
}
