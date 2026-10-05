import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'glass.dart';

GlassVariantConstants _v(
  Map<String, Object?> j,
  String key,
  GlassVariantConstants base,
) => GlassVariantConstants.fromJson(
  (j[key] as Map?)?.cast<String, Object?>() ?? const {},
  base,
);

double _d(Map<String, Object?> j, String k, double fallback) =>
    (j[k] as num?)?.toDouble() ?? fallback;

/// Reads `"#RRGGBB"` or an int ARGB value. The result is always opaque (any
/// alpha is dropped), so `toJson`'s `"#RRGGBB"` round-trips losslessly.
Color _color(Map<String, Object?> j, String k, Color fallback) {
  final v = j[k];
  if (v == null) return fallback;
  Color opaque(int argb) => Color(0xFF000000 | (argb & 0xFFFFFF));
  if (v is int) return opaque(v);
  if (v is String) {
    final hex = v.startsWith('#') ? v.substring(1) : v;
    if (hex.length == 6 || hex.length == 8) {
      return opaque(int.parse(hex, radix: 16));
    }
  }
  throw FormatException('$k: expected "#RRGGBB" or an int ARGB, got $v');
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Per-variant rendering constants (lengths in logical px).
@immutable
class GlassVariantConstants {
  /// Creates variant constants.
  const GlassVariantConstants({
    required this.blurSigma,
    this.blurSizeRef = 0,
    this.frostWideSigma = 0,
    this.frostWideMixEdge = 0,
    this.frostWideMixCentre = 0,
    this.frostWideSizeRef = 0,
    this.frostWideSizeDrop = 0,
    required this.lensBand,
    required this.lensStrength,
    required this.lensDecay,
    required this.lensSizeRef,
    required this.dispersion,
    required this.rimWidth,
    required this.rimIntensity,
    required this.fillColor,
    required this.fillOpacity,
    this.fillSizeRef = 0,
    this.fillSizeDrop = 0,
    required this.saturation,
    required this.dim,
    required this.shadowRadius,
    required this.shadowOpacity,
    required this.tintStrength,
  });

  /// Reads keys present in [j]; missing keys come from [base].
  factory GlassVariantConstants.fromJson(
    Map<String, Object?> j,
    GlassVariantConstants base,
  ) => GlassVariantConstants(
    blurSigma: _d(j, 'blurSigma', base.blurSigma),
    blurSizeRef: _d(j, 'blurSizeRef', base.blurSizeRef),
    frostWideSigma: _d(j, 'frostWideSigma', base.frostWideSigma),
    frostWideMixEdge: _d(j, 'frostWideMixEdge', base.frostWideMixEdge),
    frostWideMixCentre: _d(j, 'frostWideMixCentre', base.frostWideMixCentre),
    frostWideSizeRef: _d(j, 'frostWideSizeRef', base.frostWideSizeRef),
    frostWideSizeDrop: _d(j, 'frostWideSizeDrop', base.frostWideSizeDrop),
    lensBand: _d(j, 'lensBand', base.lensBand),
    lensStrength: _d(j, 'lensStrength', base.lensStrength),
    lensDecay: _d(j, 'lensDecay', base.lensDecay),
    lensSizeRef: _d(j, 'lensSizeRef', base.lensSizeRef),
    dispersion: _d(j, 'dispersion', base.dispersion),
    rimWidth: _d(j, 'rimWidth', base.rimWidth),
    rimIntensity: _d(j, 'rimIntensity', base.rimIntensity),
    fillColor: _color(j, 'fillColor', base.fillColor),
    fillOpacity: _d(j, 'fillOpacity', base.fillOpacity),
    fillSizeRef: _d(j, 'fillSizeRef', base.fillSizeRef),
    fillSizeDrop: _d(j, 'fillSizeDrop', base.fillSizeDrop),
    saturation: _d(j, 'saturation', base.saturation),
    dim: _d(j, 'dim', base.dim),
    shadowRadius: _d(j, 'shadowRadius', base.shadowRadius),
    shadowOpacity: _d(j, 'shadowOpacity', base.shadowOpacity),
    tintStrength: _d(j, 'tintStrength', base.tintStrength),
  );

  /// Gaussian sigma of the frost blur (logical px).
  ///
  /// Applied as `ImageFilter.blur` composed before the glass shader.
  /// Impeller blurs with a Gaussian of exactly this sigma, truncated at
  /// radius `round((σ − 0.5)·√3)` physical px and renormalised (measured in
  /// Task 15c). The truncation makes the effective blur 0.8–0.95× narrower
  /// than the requested sigma (see `docs/superpowers/notes/shader-probe.md`);
  /// fitting works with the requested value.
  final double blurSigma;

  /// Shapes whose half shorter side is below this get a proportionally
  /// smaller frost blur: σ = [blurSigma] × min(1, halfMin / blurSizeRef).
  /// 0 disables the scaling.
  ///
  /// SwiftUI frosts small glass much less than large glass (measured in Task
  /// 17b from the coded captures: regular σ grows roughly in proportion to
  /// the shape's size). A group runs one blur, so it uses the largest
  /// member's σ.
  final double blurSizeRef;

  /// Sigma of the wide frost tail added in the shader on top of the
  /// [blurSigma] core (logical px; 0 disables the tail).
  ///
  /// SwiftUI's frost is a sharp core plus a wide tail (Task 17c, measured
  /// with five code periods by `tool/fidelity/measure_frost.py`):
  /// `(1 − w)·G(core) + w·G(core ⊕ tail)`. The composed blur is the core;
  /// the shader samples the blurred texture 16 times on two rings (a 2-node
  /// Gauss–Laguerre rule for a 2-D Gaussian of this sigma) and mixes that in
  /// by the weight `w` of [frostWideMixEdge].
  final double frostWideSigma;

  /// Wide-tail weight where the lens samples at the outline; with
  /// [frostWideMixCentre] it gives `w = mix(edge, centre, sampleDepth /
  /// halfMin)`, minus the size term of [frostWideSizeRef], clamped to 0..1.
  /// `sampleDepth` is the depth of the point the lens samples, so the band
  /// (which mirrors the interior) gets the interior's weight.
  final double frostWideMixEdge;

  /// Wide-tail weight where the lens samples at the shape's centre line
  /// (sample depth = half the shorter side); see [frostWideMixEdge].
  final double frostWideMixCentre;

  /// Shapes whose half shorter side is below this lose wide-tail weight:
  /// `w −= `[frostWideSizeDrop]` × (1 − halfMin / frostWideSizeRef)`. 0
  /// disables the size term.
  final double frostWideSizeRef;

  /// Wide-tail weight lost per unit of `1 − halfMin / `[frostWideSizeRef].
  final double frostWideSizeDrop;

  /// Depth inside the outline where the edge lens ends (displacement 0).
  ///
  /// Lens v3 (measured from SwiftUI, Task 15c): at depth `d` the backdrop is
  /// sampled `lensStrength × lensBand × s × v(d)` along the outward normal,
  /// with `v(d) = (exp(-d / (lensDecay·s)) - exp(-lensBand / lensDecay)) /
  /// (1 - exp(-lensBand / lensDecay))`, clamped at 0, and the size factor
  /// `s` = min(1, half the shape's shorter side / [lensSizeRef]).
  final double lensBand;

  /// Edge displacement as a multiple of [lensBand]; negative samples inward
  /// (SwiftUI: about -2.6, so the outer pixels show content from ~47 pt
  /// inside, mirrored and compressed).
  final double lensStrength;

  /// Exponential falloff length of the lens displacement.
  final double lensDecay;

  /// Shapes whose half shorter side is below this get a uniformly scaled-down
  /// lens (band, decay and displacement × that ratio); 0 disables it.
  final double lensSizeRef;

  /// Red/blue split as a fraction of the lens displacement, weighted by the
  /// lens profile (so it sits on the outer pixels). SwiftUI shows none.
  final double dispersion;

  /// Width of the specular rim.
  final double rimWidth;

  /// Brightness added at the rim.
  final double rimIntensity;

  /// Colour the content behind the glass is washed toward (opaque; JSON
  /// `"#RRGGBB"` or an int ARGB).
  final Color fillColor;

  /// How far the content is mixed toward [fillColor] (0 = untouched).
  final double fillOpacity;

  /// Shapes whose half shorter side is below this get a weaker fill:
  /// [fillOpacity] × (1 − [fillSizeDrop] × (1 − min(1, halfMin /
  /// fillSizeRef))). 0 disables it.
  ///
  /// SwiftUI washes small regular glass less than large glass (Task 17b,
  /// measured from the coded captures: the contrast kept behind a 20 pt
  /// half-size shape is about 0.30 against 0.25 behind a 150 pt one, and
  /// dark capsules come out visibly lighter than dark rectangles).
  final double fillSizeRef;

  /// Fraction of [fillOpacity] lost on a vanishingly small shape (see
  /// [fillSizeRef]).
  final double fillSizeDrop;

  /// Saturation of the content behind the glass (1 = unchanged, 0 = grey).
  final double saturation;

  /// Darkening applied after the fill (used by `clear`).
  final double dim;

  /// Shadow falloff radius outside the shape.
  final double shadowRadius;

  /// Shadow strength at the shape edge.
  final double shadowOpacity;

  /// How strongly `.tint()` colours the glass.
  final double tintStrength;

  /// JSON form; [fillColor] is written as `"#RRGGBB"`.
  Map<String, Object> toJson() => {
    'blurSigma': blurSigma,
    'blurSizeRef': blurSizeRef,
    'frostWideSigma': frostWideSigma,
    'frostWideMixEdge': frostWideMixEdge,
    'frostWideMixCentre': frostWideMixCentre,
    'frostWideSizeRef': frostWideSizeRef,
    'frostWideSizeDrop': frostWideSizeDrop,
    'lensBand': lensBand,
    'lensStrength': lensStrength,
    'lensDecay': lensDecay,
    'lensSizeRef': lensSizeRef,
    'dispersion': dispersion,
    'rimWidth': rimWidth,
    'rimIntensity': rimIntensity,
    'fillColor': _hex(fillColor),
    'fillOpacity': fillOpacity,
    'fillSizeRef': fillSizeRef,
    'fillSizeDrop': fillSizeDrop,
    'saturation': saturation,
    'dim': dim,
    'shadowRadius': shadowRadius,
    'shadowOpacity': shadowOpacity,
    'tintStrength': tintStrength,
  };

  @override
  bool operator ==(Object other) =>
      other is GlassVariantConstants && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// Motion constants for `.interactive()` and `glassId` morphs.
@immutable
class GlassMotionConstants {
  /// Creates motion constants.
  const GlassMotionConstants({
    required this.pressScale,
    required this.pressStretch,
    required this.glowRadius,
    required this.pressResponse,
    required this.pressDamping,
    required this.morphResponse,
    required this.morphDamping,
  });

  /// Reads keys present in [j]; missing keys come from [base].
  factory GlassMotionConstants.fromJson(
    Map<String, Object?> j,
    GlassMotionConstants base,
  ) => GlassMotionConstants(
    pressScale: _d(j, 'pressScale', base.pressScale),
    pressStretch: _d(j, 'pressStretch', base.pressStretch),
    glowRadius: _d(j, 'glowRadius', base.glowRadius),
    pressResponse: _d(j, 'pressResponse', base.pressResponse),
    pressDamping: _d(j, 'pressDamping', base.pressDamping),
    morphResponse: _d(j, 'morphResponse', base.morphResponse),
    morphDamping: _d(j, 'morphDamping', base.morphDamping),
  );

  /// Uniform scale gained at full press.
  final double pressScale;

  /// Extra scale along the touch direction at full press.
  final double pressStretch;

  /// Radius of the touch glow.
  final double glowRadius;

  /// SwiftUI spring response for press/release.
  final double pressResponse;

  /// SwiftUI damping fraction for press/release.
  final double pressDamping;

  /// SwiftUI spring response for morphs.
  final double morphResponse;

  /// SwiftUI damping fraction for morphs.
  final double morphDamping;

  /// JSON form.
  Map<String, double> toJson() => {
    'pressScale': pressScale,
    'pressStretch': pressStretch,
    'glowRadius': glowRadius,
    'pressResponse': pressResponse,
    'pressDamping': pressDamping,
    'morphResponse': morphResponse,
    'morphDamping': morphDamping,
  };

  @override
  bool operator ==(Object other) =>
      other is GlassMotionConstants && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

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
    this.mergeFactor = 1.0,
    required this.motion,
  });

  /// Reads keys present in [j]; missing keys come from [standard].
  factory GlassConstants.fromJson(Map<String, Object?> j) => GlassConstants(
    regular: _v(j, 'regular', standard.regular),
    clear: _v(j, 'clear', standard.clear),
    regularDark: _v(j, 'regularDark', standard.regularDark),
    clearDark: _v(j, 'clearDark', standard.clearDark),
    cornerExponent: _d(j, 'cornerExponent', standard.cornerExponent),
    mergeFactor: _d(j, 'mergeFactor', standard.mergeFactor),
    motion: GlassMotionConstants.fromJson(
      (j['motion'] as Map?)?.cast<String, Object?>() ?? const {},
      standard.motion,
    ),
  );

  /// The shipped values (Task 17c): the edge lens measured from SwiftUI in
  /// Task 15c, refined together with every other constant by fitting the
  /// NumPy model (`tool/fidelity/fit.py`) to SwiftUI screenshots of
  /// `tool/scenes/scenes.json`; frost blur and fill scale with shape size as
  /// measured from the coded captures, and the frost wide tail
  /// (`frostWide*`, sharp core + wide component) from the Task 17c
  /// measurement (`tool/fidelity/measure_frost.py`). Device-verified on the
  /// reference simulator: 42/75 scenes pass, median SSIM 0.981, median ΔE
  /// 1.56 (`docs/superpowers/notes/fidelity-status.md`).
  static const GlassConstants standard = GlassConstants(
    // Device median SSIM/ΔE 0.988/1.65 (light, 6/12); tinted uses tintStrength.
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
    // Device median SSIM/ΔE 0.937/1.98 (4/12).
    clear: GlassVariantConstants(
      blurSigma: 1.3993,
      blurSizeRef: 0,
      frostWideSigma: 3.7541,
      frostWideMixEdge: -0.0591,
      frostWideMixCentre: 0.1981,
      frostWideSizeRef: 85.2463,
      frostWideSizeDrop: 0.0002,
      lensBand: 18.442,
      lensStrength: -2.5235,
      lensDecay: 6.5573,
      lensSizeRef: 19.0695,
      dispersion: 0.0002,
      rimWidth: 1.3411,
      rimIntensity: 0.6098,
      fillColor: Color(0xFFFEFCFC),
      fillOpacity: 0.1819,
      fillSizeRef: 0,
      fillSizeDrop: 0,
      saturation: 1.2495,
      dim: 0.0013,
      shadowRadius: 29.31,
      shadowOpacity: 0.0015,
      tintStrength: 0.35,
    ),
    // Device median SSIM/ΔE 0.978/1.59 (7/12); tinted uses tintStrength.
    regularDark: GlassVariantConstants(
      blurSigma: 11.4482,
      blurSizeRef: 81.7199,
      frostWideSigma: 7.556,
      frostWideMixEdge: 0.3985,
      frostWideMixCentre: 0.908,
      frostWideSizeRef: 79.2109,
      frostWideSizeDrop: 1.2716,
      lensBand: 18.8261,
      lensStrength: -2.6267,
      lensDecay: 5.9001,
      lensSizeRef: 38.791,
      dispersion: 0,
      rimWidth: 1.3623,
      rimIntensity: 0.3493,
      fillColor: Color(0xFF191818),
      fillOpacity: 0.6642,
      fillSizeRef: 36.0568,
      fillSizeDrop: 0.799,
      saturation: 1.8408,
      dim: 0.0147,
      shadowRadius: 20.3036,
      shadowOpacity: 0.0264,
      tintStrength: 1.0271,
    ),
    // Device median SSIM/ΔE 0.941/2.00 (4/12).
    clearDark: GlassVariantConstants(
      blurSigma: 1.3799,
      blurSizeRef: 0,
      frostWideSigma: 3.7534,
      frostWideMixEdge: -0.0595,
      frostWideMixCentre: 0.2011,
      frostWideSizeRef: 84.2326,
      frostWideSizeDrop: 0.0038,
      lensBand: 18.42,
      lensStrength: -2.529,
      lensDecay: 6.52,
      lensSizeRef: 28.86,
      dispersion: 0,
      rimWidth: 1.4229,
      rimIntensity: 0.406,
      fillColor: Color(0xFFFDFAFB),
      fillOpacity: 0.1778,
      fillSizeRef: 0,
      fillSizeDrop: 0,
      saturation: 1.2332,
      dim: 0.0006,
      shadowRadius: 13.0732,
      shadowOpacity: 0.0017,
      tintStrength: 0.35,
    ),
    cornerExponent: 2,
    // Merge scenes (device): median SSIM 0.979, ΔE 2.01.
    mergeFactor: 0.8,
    // Fitted to SwiftUI recordings (Task 16, iOS 26.4 simulator; bounding
    // box over time of press/morph clips, tool/fidelity/compare_motion.py).
    motion: GlassMotionConstants(
      // Capsule 200×56 grows 6.6% (height +11–12 px of 176 px, light and
      // dark), symmetrically: no shift toward the touch, stretch ≈ 0.01.
      // SwiftUI scales small shapes more (72 pt circle: +22%), which one
      // uniform factor cannot follow.
      pressScale: 0.066,
      pressStretch: 0.011,
      // Gaussian σ of the touch glow: SwiftUI 42.7–44.5 pt; 41 measures
      // 43.5 in Flutter. SwiftUI's glow is 3–10× fainter than the shader's
      // fixed 0.25 amplitude.
      glowRadius: 41,
      // SwiftUI press-in (0.34, 0.52) and release (0.38, 0.57), mean
      // (0.36, 0.54) over two runs; one spring serves both here, set so that
      // Flutter measures the same mean (0.36, 0.54 ± 0.04).
      pressResponse: 0.36,
      pressDamping: 0.56,
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
      other.mergeFactor == mergeFactor &&
      other.motion == motion;

  @override
  int get hashCode => Object.hash(
    regular,
    clear,
    regularDark,
    clearDark,
    cornerExponent,
    mergeFactor,
    motion,
  );
}
