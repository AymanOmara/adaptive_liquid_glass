import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'glass_json.dart';
import 'glass_motion_constants.dart';
import 'glass_variant.dart';
import 'glass_variant_constants.dart';

/// All fitted constants. Exported from `testing.dart` only.
@immutable
class GlassConstants {
  /// Creates a constants set.
  const GlassConstants({
    required this.regular,
    required this.clear,
    required this.regularDark,
    required this.clearDark,
    required this.cornerExponent,
    this.cornerZone = 1.0,
    this.mergeFactor = 1.0,
    required this.motion,
  });

  /// Reads keys present in [j]; missing keys come from [standard].
  factory GlassConstants.fromJson(Map<String, Object?> j) => GlassConstants(
    regular: GlassJson.variant(j, 'regular', standard.regular),
    clear: GlassJson.variant(j, 'clear', standard.clear),
    regularDark: GlassJson.variant(j, 'regularDark', standard.regularDark),
    clearDark: GlassJson.variant(j, 'clearDark', standard.clearDark),
    cornerExponent: GlassJson.number(
      j,
      'cornerExponent',
      standard.cornerExponent,
    ),
    cornerZone: GlassJson.number(j, 'cornerZone', standard.cornerZone),
    mergeFactor: GlassJson.number(j, 'mergeFactor', standard.mergeFactor),
    motion: GlassMotionConstants.fromJson(
      (j['motion'] as Map?)?.cast<String, Object?>() ?? const {},
      standard.motion,
    ),
  );

  /// The shipped values (certified at the Task A1 tree): the Task
  /// 17c constants (edge lens from Task 15c, size-dependent frost/fill from
  /// 17b, frost wide tail from 17c) plus the 17d additions (tone LUT, small
  /// dark-shape tone lift, clear lens grid, anisotropic frost) and the A1
  /// continuous-corner outline, fitted by
  /// the NumPy model (`tool/fidelity/fit.py`) against SwiftUI screenshots
  /// of `tool/scenes/scenes.json`. Device-certified on the reference
  /// simulator: 46/75 scenes pass, median SSIM 0.9830 / median ΔE 1.09,
  /// min SSIM 0.9532, 0 scenes below 0.95 (75 in-set scenes; pre-A1 held-out
  /// 48-scene set: 18/48, min 0.9470). Per-set and per-scene numbers, and
  /// the known residuals, live in
  /// `docs/superpowers/notes/fidelity-status.md` — cite that note, not
  /// per-set numbers here.
  static const GlassConstants standard = GlassConstants(
    // Tinted uses tintStrength.
    regular: GlassVariantConstants(
      blurSigma: 5.9236,
      blurSizeRef: 59.9762,
      frostWideSigma: 7.0367,
      frostWideMixEdge: 0.4052,
      frostWideMixCentre: 0.9298,
      frostWideSizeRef: 75.4199,
      frostWideSizeDrop: 1.1423,
      lensBand: 18.2615,
      lensStrength: -2.6351,
      lensDecay: 6.1712,
      lensSizeRef: 38.2208,
      dispersion: 0.0003,
      rimWidth: 1.2454,
      rimIntensity: 0.2315,
      fillColor: Color(0xFFFEFDFD),
      fillOpacity: 0.6804,
      fillSizeRef: 43.9952,
      fillSizeDrop: 0.1268,
      saturation: 1.7415,
      dim: 0.0046,
      shadowRadius: 20.8906,
      shadowOpacity: 0.0494,
      tintStrength: 1.0219,
    ),
    clear: GlassVariantConstants(
      blurSigma: 1.2,
      blurSizeRef: 0,
      frostWideSigma: 1.7973,
      frostWideMixEdge: -0.0117,
      frostWideMixCentre: 0.7589,
      frostWideSizeRef: 85.2463,
      frostWideSizeDrop: 0.0002,
      toneKnots: [0, 0.0289, 0.1865, 0.3476, 0.5063, 0.6651, 0.8265, 0.9772, 1],
      postBlurShare: 0.45,
      normalRadiusScale: 1.55,
      lensEdge: 9,
      rimMix: 0.63,
      lensBand: 18.442,
      lensStrength: -2.54,
      lensDecay: 6.5573,
      lensSizeRef: 28.8,
      dispersion: 0,
      rimWidth: 1.2475,
      rimIntensity: 0,
      fillColor: Color(0xFFFEFCFC),
      fillOpacity: 0.1705,
      fillSizeRef: 0,
      fillSizeDrop: 0,
      saturation: 0.9726,
      dim: 0.0013,
      shadowRadius: 29.31,
      shadowOpacity: 0.0015,
      tintStrength: 0.35,
    ),
    regularDark: GlassVariantConstants(
      blurSigma: 8.2468,
      blurSizeRef: 78.0334,
      frostWideSigma: 7.556,
      frostWideMixEdge: 1.0836,
      frostWideMixCentre: 0.908,
      frostWideSizeRef: 79.2109,
      frostWideSizeDrop: 2.7378,
      toneLift: 0.7827,
      toneLiftKnee: 0.9995,
      toneLiftSizeRef: 48.0387,
      blurAspectPower: 0.28,
      lensBand: 18.8261,
      lensStrength: -2.6267,
      lensDecay: 5.9001,
      lensSizeRef: 38.791,
      dispersion: 0,
      rimWidth: 1.3623,
      rimIntensity: 0.3493,
      fillColor: Color(0xFF1B1817),
      fillOpacity: 0.665,
      fillSizeRef: 36.0728,
      fillSizeDrop: 0.798,
      saturation: 1.8791,
      dim: 0.001,
      shadowRadius: 20.3036,
      shadowOpacity: 0.0264,
      tintStrength: 1.0084,
    ),
    clearDark: GlassVariantConstants(
      blurSigma: 1.1534,
      blurSizeRef: 0,
      frostWideSigma: 1.9152,
      frostWideMixEdge: 0.0296,
      frostWideMixCentre: 0.7809,
      frostWideSizeRef: 84.2326,
      frostWideSizeDrop: 0.0038,
      toneKnots: [
        0,
        0.0519091586529797,
        0.213090511337508,
        0.3630962727280779,
        0.5198145752907551,
        0.679180921179765,
        0.8347696966236444,
        0.9910065350260904,
        1,
      ],
      postBlurShare: 0.2882,
      normalRadiusScale: 1.5358,
      lensEdge: 10.5854,
      lensEdgeDecay: 0.4954,
      rimMix: 0.5247,
      rimMixWidth: 1.1782,
      rimMixCut: 3.9722,
      rimMixLumaFloor: 0.05,
      lensBand: 18.3411,
      lensStrength: -2.54,
      lensDecay: 6.6262,
      lensSizeRef: 28.7,
      dispersion: 0,
      rimWidth: 1.2475,
      rimIntensity: 0,
      fillColor: Color(0xFFFDFAFB),
      fillOpacity: 0.1581,
      fillSizeRef: 0,
      fillSizeDrop: 0,
      saturation: 0.9633,
      dim: 0.0006,
      shadowRadius: 13.0732,
      shadowOpacity: 0.0017,
      tintStrength: 0.35,
    ),
    cornerExponent: 2,
    // Task A1 (model sweep 1.0-1.6 against SwiftUI's `.continuous` rects,
    // then device): outline only; the lens normals keep circular corners.
    cornerZone: 1.2,
    // Merge scenes (device): median SSIM 0.979, ΔE 2.01.
    mergeFactor: 0.8,
    // Fitted to SwiftUI recordings (Task 16, iOS 26.4 simulator; bounding
    // box over time of press/morph clips, tool/fidelity/compare_motion.py).
    motion: GlassMotionConstants(
      // Task 16b: lossless captures (in-app render-server crop, identical
      // to screenshots), iOS 26.4 simulator, compare_motion.py bboxes.
      // SwiftUI adds about the same area to every pressed shape: centre
      // presses of circles 44/72/120 pt and capsules 120×44/200×56/300×72
      // grow by scale 1.356/1.229/1.069 and 1.136/1.072/1.041. Least
      // squares on the long-side growth (pt) of sqrt(1 + G/(w·h)), capped:
      // G 1796, cap 1.356, RMS 2.4 pt (worst: 72 pt circle, 11.5 vs
      // 16.5 pt). Below 44 pt the cap is unmeasured.
      pressGrowthArea: 1800,
      pressScaleMax: 1.36,
      // SwiftUI (sx − sy)/0.79 = 0.0055 on the 200×56 capsule; Flutter
      // measured 0.0103 at 0.011.
      pressStretch: 0.006,
      // Gaussian σ of the touch glow: SwiftUI 42.3 (light) / 42.5 (dark) pt,
      // Flutter at 41 measured 46.0 / 40.9. SwiftUI's glow is 6–9× fainter
      // (lift 0.019 vs 0.175 light, 0.041 vs 0.238 dark): the shader's
      // amplitude, not fitted here.
      glowRadius: 40,
      // Press-in and release differ: SwiftUI (0.280, 0.633) in and
      // (0.383, 0.545) out (median over 7 clips, bbox height). Circles
      // release under-damped (ζ ≈ 0.37), capsules at 0.51–0.76. Flutter
      // at these values measures (0.274, 0.625) and (0.375, 0.554).
      pressResponse: 0.28,
      pressDamping: 0.63,
      releaseResponse: 0.38,
      releaseDamping: 0.55,
      // `withAnimation(.bouncy)` morphs measure (0.50, 0.72): `.bouncy`
      // (response 0.5, bounce 0.3); Flutter at these values measures
      // (0.50, 0.69).
      morphResponse: 0.5,
      morphDamping: 0.7,
    ),
  );

  /// Regular-glass constants.
  final GlassVariantConstants regular;

  /// Clear-glass constants.
  final GlassVariantConstants clear;

  /// Regular glass in dark mode.
  final GlassVariantConstants regularDark;

  /// Clear glass in dark mode.
  final GlassVariantConstants clearDark;

  /// Superellipse exponent approximating Apple's continuous corners.
  ///
  /// Used for rectangles only; capsules and circles use exact circular arcs
  /// (exponent 2), like SwiftUI's `Capsule()` and `Circle()`.
  final double cornerExponent;

  /// Continuous-corner zone, as a multiple of the corner radius.
  ///
  /// Above 1 a rectangle's corner curve starts `cornerZone × radius` from
  /// the corner (capped at half the shorter side) and is a superellipse
  /// whose exponent is derived so it passes through the circular arc's 45°
  /// point, like Apple's continuous corners; it becomes a circular arc when
  /// the zone clamps to the radius (pills). 1 keeps [cornerExponent] with
  /// the curve starting at the radius. Applies to the outline only; capsules
  /// and circles stay exact circles. Fitted, not measured: see
  /// `docs/superpowers/notes/fidelity-status.md` (Task A1).
  final double cornerZone;

  /// Returns a copy with the given fields replaced.
  GlassConstants copyWith({
    GlassVariantConstants? regular,
    GlassVariantConstants? clear,
    GlassVariantConstants? regularDark,
    GlassVariantConstants? clearDark,
    double? cornerExponent,
    double? cornerZone,
    double? mergeFactor,
    GlassMotionConstants? motion,
  }) => GlassConstants(
    regular: regular ?? this.regular,
    clear: clear ?? this.clear,
    regularDark: regularDark ?? this.regularDark,
    clearDark: clearDark ?? this.clearDark,
    cornerExponent: cornerExponent ?? this.cornerExponent,
    cornerZone: cornerZone ?? this.cornerZone,
    mergeFactor: mergeFactor ?? this.mergeFactor,
    motion: motion ?? this.motion,
  );

  /// Smooth-union radius as a multiple of the group's spacing.
  final double mergeFactor;

  /// Motion constants.
  final GlassMotionConstants motion;

  /// Constants for [variant] in [brightness]; `identity` never draws, so it
  /// maps to regular.
  GlassVariantConstants of(
    GlassVariant variant, [
    Brightness brightness = Brightness.light,
  ]) {
    final dark = brightness == Brightness.dark;
    if (variant == GlassVariant.clear) return dark ? clearDark : clear;
    return dark ? regularDark : regular;
  }

  /// JSON form.
  Map<String, Object?> toJson() => {
    'regular': regular.toJson(),
    'clear': clear.toJson(),
    'regularDark': regularDark.toJson(),
    'clearDark': clearDark.toJson(),
    'cornerExponent': cornerExponent,
    'cornerZone': cornerZone,
    'mergeFactor': mergeFactor,
    'motion': motion.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is GlassConstants &&
      other.regular == regular &&
      other.clear == clear &&
      other.regularDark == regularDark &&
      other.clearDark == clearDark &&
      other.cornerExponent == cornerExponent &&
      other.cornerZone == cornerZone &&
      other.mergeFactor == mergeFactor &&
      other.motion == motion;

  @override
  int get hashCode => Object.hash(
    regular,
    clear,
    regularDark,
    clearDark,
    cornerExponent,
    cornerZone,
    mergeFactor,
    motion,
  );
}
