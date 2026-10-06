import 'package:flutter/widgets.dart';

import 'glass_uniforms.dart';

/// What the last paint computed; for tests.
@immutable
class GlassBackdropDebugFrame {
  /// Creates a debug frame.
  const GlassBackdropDebugFrame(
    this.uniforms,
    this.localBounds,
    this.filterOriginGlobal,
    this.blurSigma, [
    this.blurAspect = 1,
  ]);

  /// Uniforms sent to the shader.
  final GlassFrameUniforms uniforms;

  /// Clip rect, local to the render object.
  final Rect localBounds;

  /// Global logical position of the clip origin.
  final Offset filterOriginGlobal;

  /// Sigma (logical px) of the frost blur composed before the shader (the
  /// geometric mean of its x and y sigmas).
  final double blurSigma;

  /// sigmaX / [blurSigma] (sigmaY = [blurSigma] / blurAspect); 1 = isotropic
  /// (`blurAspectPower`).
  final double blurAspect;
}
