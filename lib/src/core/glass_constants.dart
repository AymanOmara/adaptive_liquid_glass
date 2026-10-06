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

/// Reads a 9-entry knot list; a malformed one falls back to [fallback].
List<double> _knots(Map<String, Object?> j, String k, List<double> fallback) {
  final v = j[k];
  if (v is List && v.length == 9 && v.every((e) => e is num)) {
    return List.unmodifiable([for (final e in v) (e as num).toDouble()]);
  }
  return fallback;
}

/// [mapEquals] compares list values by identity, which breaks `==` across
/// JSON round-trips now that [GlassVariantConstants] carries [List<double>]
/// knots; compare top-level lists by contents.
bool _jsonEquals(Map<String, Object?> a, Map<String, Object?> b) =>
    a.length == b.length &&
    a.entries.every(
      (e) =>
          identical(e.value, b[e.key]) ||
          (e.value is List && b[e.key] is List
              ? listEquals(e.value as List, b[e.key] as List)
              : e.value == b[e.key]),
    );

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
  /// Grey tone LUT output knots at inputs `i / 8`, `i = 0..8`
  /// ([identityToneKnots] reproduces the input exactly).
  static const List<double> identityToneKnots = [
    0,
    0.125,
    0.25,
    0.375,
    0.5,
    0.625,
    0.75,
    0.875,
    1,
  ];

  /// Creates variant constants.
  const GlassVariantConstants({
    required this.blurSigma,
    this.blurSizeRef = 0,
    this.frostWideSigma = 0,
    this.frostWideMixEdge = 0,
    this.frostWideMixCentre = 0,
    this.frostWideSizeRef = 0,
    this.frostWideSizeDrop = 0,
    this.toneKnots = identityToneKnots,
    this.glowStrength = 0.25,
    this.postBlurShare = 0,
    this.normalRadiusScale = 1,
    this.lensEdge = 0,
    this.lensEdgeDecay = 0.6,
    this.rimMix = 0,
    this.rimMixWidth = 1.5,
    this.rimMixCut = 1,
    this.rimMixLumaFloor = 1,
    this.toneLift = 0,
    this.blurAspectPower = 0,
    this.rimBack = 0.35,
    this.lensVertical = 0,
    this.rimTint = 0,
    this.rimHue = 0,
    this.toneLiftKnee = 0.5,
    this.toneLiftSizeRef = 0,
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
    toneKnots: _knots(j, 'toneKnots', base.toneKnots),
    glowStrength: _d(j, 'glowStrength', base.glowStrength),
    postBlurShare: _d(j, 'postBlurShare', base.postBlurShare),
    normalRadiusScale: _d(j, 'normalRadiusScale', base.normalRadiusScale),
    lensEdge: _d(j, 'lensEdge', base.lensEdge),
    lensEdgeDecay: _d(j, 'lensEdgeDecay', base.lensEdgeDecay),
    rimMix: _d(j, 'rimMix', base.rimMix),
    rimMixWidth: _d(j, 'rimMixWidth', base.rimMixWidth),
    rimMixCut: _d(j, 'rimMixCut', base.rimMixCut),
    rimMixLumaFloor: _d(j, 'rimMixLumaFloor', base.rimMixLumaFloor),
    toneLift: _d(j, 'toneLift', base.toneLift),
    blurAspectPower: _d(j, 'blurAspectPower', base.blurAspectPower),
    rimBack: _d(j, 'rimBack', base.rimBack),
    lensVertical: _d(j, 'lensVertical', base.lensVertical),
    rimTint: _d(j, 'rimTint', base.rimTint),
    rimHue: _d(j, 'rimHue', base.rimHue),
    toneLiftKnee: _d(j, 'toneLiftKnee', base.toneLiftKnee),
    toneLiftSizeRef: _d(j, 'toneLiftSizeRef', base.toneLiftSizeRef),
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
  /// Negative splits red from green and blue together (iOS's tab lens),
  /// so a blue tint fringes in shades of blue rather than green.
  final double dispersion;

  /// Grey tone curve applied to the frosted backdrop: piecewise linear
  /// through these output knots at inputs `i / 8`, after the saturation and
  /// before the fill wash (Task 17d, seeded from flat-grey captures and
  /// fitted). [identityToneKnots] disables it.
  final List<double> toneKnots;

  /// Brightness of the touch glow at full press (Task 17d; 0.25 is the
  /// pre-17d behaviour, left for the motion fit).
  final double glowStrength;

  /// Share of the frost blur's variance applied after the lens instead of
  /// before it (0..0.9; Task 17d, clear glass). The composed blur becomes
  /// σ·√(1 − share) and the shader adds σ·√share in screen space, mapped
  /// through the lens, so the refracted band is blurred like SwiftUI's.
  final double postBlurShare;

  /// Lens normals follow a rounder outline: each corner radius × this,
  /// capped at half the shorter side (Task 17d, measured: 1.5–1.6 on
  /// SwiftUI rects). 1 uses the outline itself; capsules and circles are
  /// unaffected.
  final double normalRadiusScale;

  /// Extra inward lens offset at the outline (logical px), falling off as
  /// `exp(−depth / lensEdgeDecay)` (Task 17d, measured: SwiftUI's lens is
  /// steeper in the outer 1–2 pt). 0 disables it.
  final double lensEdge;

  /// Falloff length of [lensEdge] (logical px).
  final double lensEdgeDecay;

  /// Isotropic rim: the outer pixels mix toward white by this alpha,
  /// ramping to 0 at [rimMixWidth] and cut at [rimMixCut] (Task 17d,
  /// measured on clear glass). 0 disables it.
  final double rimMix;

  /// Depth (logical px) where the [rimMix] ramp reaches 0.
  final double rimMixWidth;

  /// Depth (logical px) where [rimMix] is cut off (a 1 px smoothstep).
  final double rimMixCut;

  /// [rimMix] is scaled by `floor + (1 − floor)·min(1, luma / 0.5)` of the
  /// glass under it; 1 disables the scaling (dark mode measured 0.05).
  final double rimMixLumaFloor;

  /// Small-shape shadow lift (Task 17d / 8b, fitted on dark regular glass):
  /// after the tone LUT each channel gains `toneLift × size × max(0, 1 −
  /// c / toneLiftKnee)²`, with `size = max(0, 1 − halfMin /
  /// toneLiftSizeRef)`. SwiftUI lifts the dark end behind small dark glass
  /// (a capsule over a dark photo reads grey, not black). 0 disables it.
  final double toneLift;

  /// Anisotropic frost (Task 17d, fitted from SwiftUI's directional detail
  /// on dark regular capsules: a wide shape keeps more detail along its long
  /// axis): sigmaX = σ·(h/w)^power, sigmaY = σ·(w/h)^power. 0 = isotropic.
  final double blurAspectPower;

  /// Input level where [toneLift] fades to 0.
  final double toneLiftKnee;

  /// Half shorter side (logical px) at and above which [toneLift] is 0;
  /// 0 disables the lift.
  final double toneLiftSizeRef;

  /// Width of the specular rim.
  final double rimWidth;

  /// Brightness added at the rim.
  final double rimIntensity;

  /// Rim strength on the side facing away from the light, relative to the
  /// lit side (0.35 = the pre-17d literal, shipped unfitted). Task 9
  /// measured a fixed light with a directional mismatch — the device rim is
  /// brightest around 135°, where the model's 315° light is weakest — so
  /// this key exists for a bounded refit; it is not itself the measured
  /// far/near ratio.
  final double rimBack;

  /// How much the lens (main and edge terms) is limited to where the
  /// outline faces up or down: 0 bends all round (the default); 1 leaves
  /// the sideways-facing outline unbent, so a horizontal capsule's round
  /// ends stay clear (iOS 26's tab lens, fitted to Kept).
  final double lensVertical;

  /// How far the isotropic rim ([rimMix]) turns from white towards
  /// [rimHue] (0 = white, the default; iOS 26's tab lens has a teal rim).
  final double rimTint;

  /// Hue of [rimTint], in degrees.
  final double rimHue;

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
    'toneKnots': toneKnots,
    'glowStrength': glowStrength,
    'postBlurShare': postBlurShare,
    'normalRadiusScale': normalRadiusScale,
    'lensEdge': lensEdge,
    'lensEdgeDecay': lensEdgeDecay,
    'rimMix': rimMix,
    'rimMixWidth': rimMixWidth,
    'rimMixCut': rimMixCut,
    'rimMixLumaFloor': rimMixLumaFloor,
    'toneLift': toneLift,
    'blurAspectPower': blurAspectPower,
    'rimBack': rimBack,
    'lensVertical': lensVertical,
    'rimTint': rimTint,
    'rimHue': rimHue,
    'toneLiftKnee': toneLiftKnee,
    'toneLiftSizeRef': toneLiftSizeRef,
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
      other is GlassVariantConstants && _jsonEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(
    toJson().values.map((v) => v is List ? Object.hashAll(v) : v),
  );
}

/// Motion constants for `.interactive()` and `glassId` morphs.
@immutable
class GlassMotionConstants {
  /// Creates motion constants.
  const GlassMotionConstants({
    required this.pressGrowthArea,
    required this.pressScaleMax,
    required this.pressStretch,
    required this.glowRadius,
    required this.pressResponse,
    required this.pressDamping,
    required this.releaseResponse,
    required this.releaseDamping,
    required this.morphResponse,
    required this.morphDamping,
  });

  /// Reads keys present in [j]; missing keys come from [base].
  factory GlassMotionConstants.fromJson(
    Map<String, Object?> j,
    GlassMotionConstants base,
  ) => GlassMotionConstants(
    pressGrowthArea: _d(j, 'pressGrowthArea', base.pressGrowthArea),
    pressScaleMax: _d(j, 'pressScaleMax', base.pressScaleMax),
    pressStretch: _d(j, 'pressStretch', base.pressStretch),
    glowRadius: _d(j, 'glowRadius', base.glowRadius),
    pressResponse: _d(j, 'pressResponse', base.pressResponse),
    pressDamping: _d(j, 'pressDamping', base.pressDamping),
    releaseResponse: _d(j, 'releaseResponse', base.releaseResponse),
    releaseDamping: _d(j, 'releaseDamping', base.releaseDamping),
    morphResponse: _d(j, 'morphResponse', base.morphResponse),
    morphDamping: _d(j, 'morphDamping', base.morphDamping),
  );

  /// Area (pt²) a pressed shape gains at full press: its uniform scale is
  /// `sqrt(1 + pressGrowthArea / (w·h))`, capped at [pressScaleMax], so
  /// small shapes grow more than large ones.
  final double pressGrowthArea;

  /// Largest uniform press scale.
  final double pressScaleMax;

  /// Extra scale along the touch direction at full press.
  final double pressStretch;

  /// Radius of the touch glow.
  final double glowRadius;

  /// SwiftUI spring response for the press-in.
  final double pressResponse;

  /// SwiftUI damping fraction for the press-in.
  final double pressDamping;

  /// SwiftUI spring response for the release.
  final double releaseResponse;

  /// SwiftUI damping fraction for the release.
  final double releaseDamping;

  /// SwiftUI spring response for morphs.
  final double morphResponse;

  /// SwiftUI damping fraction for morphs.
  final double morphDamping;

  /// JSON form.
  Map<String, double> toJson() => {
    'pressGrowthArea': pressGrowthArea,
    'pressScaleMax': pressScaleMax,
    'pressStretch': pressStretch,
    'glowRadius': glowRadius,
    'pressResponse': pressResponse,
    'pressDamping': pressDamping,
    'releaseResponse': releaseResponse,
    'releaseDamping': releaseDamping,
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

  /// The shipped values (certified at the final Task 17d tree): the Task
  /// 17c constants (edge lens from Task 15c, size-dependent frost/fill from
  /// 17b, frost wide tail from 17c) plus the 17d additions (tone LUT, small
  /// dark-shape tone lift, clear lens grid, anisotropic frost), fitted by
  /// the NumPy model (`tool/fidelity/fit.py`) against SwiftUI screenshots
  /// of `tool/scenes/scenes.json`. Device-certified on the reference
  /// simulator: 46/75 scenes pass, median SSIM 0.9828 / median ΔE 1.09,
  /// min SSIM 0.9532, 0 scenes below 0.95 (75 in-set scenes; held-out
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

  /// Returns a copy with the given fields replaced.
  GlassConstants copyWith({
    GlassVariantConstants? regular,
    GlassVariantConstants? clear,
    GlassVariantConstants? regularDark,
    GlassVariantConstants? clearDark,
    double? cornerExponent,
    double? mergeFactor,
    GlassMotionConstants? motion,
  }) => GlassConstants(
    regular: regular ?? this.regular,
    clear: clear ?? this.clear,
    regularDark: regularDark ?? this.regularDark,
    clearDark: clearDark ?? this.clearDark,
    cornerExponent: cornerExponent ?? this.cornerExponent,
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
