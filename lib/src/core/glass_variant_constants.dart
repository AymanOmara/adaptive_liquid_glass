import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'glass_json.dart';

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
    this.smallToneKnots = identityToneKnots,
    this.smallSizeLo = 0,
    this.smallSizeHi = 0,
    this.postJacobianMax = 4,
    this.ambientMix = 0,
    this.ambientReach = 0,
    this.shadowOffsetY = 0,
    this.dispersionTangent = 0,
    this.lensEllipse = 0,
    this.backdropInset = 0,
    this.ambientLift = 0,
    this.backdropReach = 0,
    this.bandSplitDrop = 0,
    this.toneLumaMix = 0,
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
    blurSigma: GlassJson.number(j, 'blurSigma', base.blurSigma),
    blurSizeRef: GlassJson.number(j, 'blurSizeRef', base.blurSizeRef),
    frostWideSigma: GlassJson.number(j, 'frostWideSigma', base.frostWideSigma),
    frostWideMixEdge: GlassJson.number(
      j,
      'frostWideMixEdge',
      base.frostWideMixEdge,
    ),
    frostWideMixCentre: GlassJson.number(
      j,
      'frostWideMixCentre',
      base.frostWideMixCentre,
    ),
    frostWideSizeRef: GlassJson.number(
      j,
      'frostWideSizeRef',
      base.frostWideSizeRef,
    ),
    frostWideSizeDrop: GlassJson.number(
      j,
      'frostWideSizeDrop',
      base.frostWideSizeDrop,
    ),
    toneKnots: GlassJson.knots(j, 'toneKnots', base.toneKnots),
    smallToneKnots: GlassJson.knots(j, 'smallToneKnots', base.smallToneKnots),
    smallSizeLo: GlassJson.number(j, 'smallSizeLo', base.smallSizeLo),
    smallSizeHi: GlassJson.number(j, 'smallSizeHi', base.smallSizeHi),
    postJacobianMax: GlassJson.number(
      j,
      'postJacobianMax',
      base.postJacobianMax,
    ),
    ambientMix: GlassJson.number(j, 'ambientMix', base.ambientMix),
    ambientReach: GlassJson.number(j, 'ambientReach', base.ambientReach),
    shadowOffsetY: GlassJson.number(j, 'shadowOffsetY', base.shadowOffsetY),
    dispersionTangent: GlassJson.number(
      j,
      'dispersionTangent',
      base.dispersionTangent,
    ),
    lensEllipse: GlassJson.number(j, 'lensEllipse', base.lensEllipse),
    backdropInset: GlassJson.number(j, 'backdropInset', base.backdropInset),
    ambientLift: GlassJson.number(j, 'ambientLift', base.ambientLift),
    backdropReach: GlassJson.number(j, 'backdropReach', base.backdropReach),
    bandSplitDrop: GlassJson.number(j, 'bandSplitDrop', base.bandSplitDrop),
    toneLumaMix: GlassJson.number(j, 'toneLumaMix', base.toneLumaMix),
    glowStrength: GlassJson.number(j, 'glowStrength', base.glowStrength),
    postBlurShare: GlassJson.number(j, 'postBlurShare', base.postBlurShare),
    normalRadiusScale: GlassJson.number(
      j,
      'normalRadiusScale',
      base.normalRadiusScale,
    ),
    lensEdge: GlassJson.number(j, 'lensEdge', base.lensEdge),
    lensEdgeDecay: GlassJson.number(j, 'lensEdgeDecay', base.lensEdgeDecay),
    rimMix: GlassJson.number(j, 'rimMix', base.rimMix),
    rimMixWidth: GlassJson.number(j, 'rimMixWidth', base.rimMixWidth),
    rimMixCut: GlassJson.number(j, 'rimMixCut', base.rimMixCut),
    rimMixLumaFloor: GlassJson.number(
      j,
      'rimMixLumaFloor',
      base.rimMixLumaFloor,
    ),
    toneLift: GlassJson.number(j, 'toneLift', base.toneLift),
    blurAspectPower: GlassJson.number(
      j,
      'blurAspectPower',
      base.blurAspectPower,
    ),
    rimBack: GlassJson.number(j, 'rimBack', base.rimBack),
    lensVertical: GlassJson.number(j, 'lensVertical', base.lensVertical),
    rimTint: GlassJson.number(j, 'rimTint', base.rimTint),
    rimHue: GlassJson.number(j, 'rimHue', base.rimHue),
    toneLiftKnee: GlassJson.number(j, 'toneLiftKnee', base.toneLiftKnee),
    toneLiftSizeRef: GlassJson.number(
      j,
      'toneLiftSizeRef',
      base.toneLiftSizeRef,
    ),
    lensBand: GlassJson.number(j, 'lensBand', base.lensBand),
    lensStrength: GlassJson.number(j, 'lensStrength', base.lensStrength),
    lensDecay: GlassJson.number(j, 'lensDecay', base.lensDecay),
    lensSizeRef: GlassJson.number(j, 'lensSizeRef', base.lensSizeRef),
    dispersion: GlassJson.number(j, 'dispersion', base.dispersion),
    rimWidth: GlassJson.number(j, 'rimWidth', base.rimWidth),
    rimIntensity: GlassJson.number(j, 'rimIntensity', base.rimIntensity),
    fillColor: GlassJson.color(j, 'fillColor', base.fillColor),
    fillOpacity: GlassJson.number(j, 'fillOpacity', base.fillOpacity),
    fillSizeRef: GlassJson.number(j, 'fillSizeRef', base.fillSizeRef),
    fillSizeDrop: GlassJson.number(j, 'fillSizeDrop', base.fillSizeDrop),
    saturation: GlassJson.number(j, 'saturation', base.saturation),
    dim: GlassJson.number(j, 'dim', base.dim),
    shadowRadius: GlassJson.number(j, 'shadowRadius', base.shadowRadius),
    shadowOpacity: GlassJson.number(j, 'shadowOpacity', base.shadowOpacity),
    tintStrength: GlassJson.number(j, 'tintStrength', base.tintStrength),
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

  /// Grey tone LUT for small shapes: Task g13: measured on the reference
  /// simulator — SwiftUI switches small shapes (half shorter side <= ~32 pt)
  /// to a steeper tone response; this LUT is applied after the fill wash and
  /// dim, weighted from 1 at [smallSizeLo] to 0 at [smallSizeHi].
  /// [identityToneKnots] disables it.
  final List<double> smallToneKnots;

  /// Half shorter side (logical px) at and below which [smallToneKnots] is
  /// applied at full weight (Task g13).
  final double smallSizeLo;

  /// Half shorter side (logical px) at and above which [smallToneKnots] is
  /// off; the weight is linear in between. The feature is off when this is
  /// <= 0 (Task g13).
  final double smallSizeHi;

  /// Largest stretch of the post-lens blur taps through the lens's Jacobian
  /// (fidelity group 4: SwiftUI's clear-glass blur stays ~1.1-1.4 pt into the
  /// outer 4 pt of the band). 4 is the original clamp.
  final double postJacobianMax;

  /// Strength of the ambient colour (item 8): the glass adds this times the
  /// chroma (colour minus its luma) of the blurred backdrop's average over
  /// the shape, as SwiftUI's large regular glass carries the backdrop's
  /// average hue. Off in the small-shape class; 0 = off.
  final double ambientMix;

  /// How far (pt) the ambient colour's average reaches beyond the shape's
  /// rect on each side (item 8).
  final double ambientReach;

  /// How far (pt) the shadow ([shadowRadius]) is moved down; 0 centres it
  /// on the shape.
  final double shadowOffsetY;

  /// A sideways colour split along the outline, as a share of the lens's
  /// displacement: red and blue taps move in opposite directions along the
  /// rim, so a band's fringe is warm at one end and cool at the other (iOS
  /// 26.4's tab lens). 0 splits only along the normal ([dispersion]).
  final double dispersionTangent;

  /// How far (0-1) the lens bends along the normals of the ellipse
  /// inscribed in the shape instead of the outline's: along a capsule's
  /// flat sides the bend turns gradually towards the round ends (iOS 26.4's
  /// tab lens: its bands thin smoothly towards the ends). 0 = the outline.
  final double lensEllipse;

  /// When > 0, the glass refracts only the backdrop between its top and
  /// bottom inset by this much (logical px); what it would bend in from
  /// beyond reads black. iOS 26.4's tab lens overhangs the bar by this
  /// much and bends in only the bar, so its bands above and below stay
  /// dark over any page. 0 = the whole backdrop.
  final double backdropInset;

  /// How much the whole glass lightens with the average luma of the
  /// backdrop under it beyond 0.2 (less where the backdrop behind a pixel
  /// is already light). iOS 26.4's tab bar does: over bright content its
  /// dark glass lightens as a whole. 0 = off.
  final double ambientLift;

  /// How far (logical px) beyond the band [backdropInset] leaves the glass
  /// still refracts: iOS 26.4's tab lens shows the bar's edge, its shadow
  /// and the page right by it (their fringes are its rainbow in light
  /// mode), never the page further out.
  final double backdropReach;

  /// How much of the colour split across the rim is dropped where the
  /// glass reaches past [backdropInset]'s band: 1 keeps only the split
  /// along the rim there. iOS 26.4's dark tab lens shows its overhang
  /// near black (the split tinted it blue with the bar); its light lens
  /// keeps the rainbow (0).
  final double bandSplitDrop;

  /// How far the tone LUT is keyed on luma instead of applied per channel
  /// (item 8 round 3): at 1 the LUT moves the frosted backdrop's luma and
  /// its chroma rides along unchanged; 0 = per channel, as before.
  final double toneLumaMix;

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
  /// Negative splits the rim's colour by side instead, by this much:
  /// with [rimHue] 180, cooler where the outline faces left and warmer
  /// where it faces right (iOS 26's dark tab lens); with 0, the reverse
  /// (its light lens).
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
    'smallToneKnots': smallToneKnots,
    'smallSizeLo': smallSizeLo,
    'smallSizeHi': smallSizeHi,
    'postJacobianMax': postJacobianMax,
    'ambientMix': ambientMix,
    'ambientReach': ambientReach,
    'shadowOffsetY': shadowOffsetY,
    'dispersionTangent': dispersionTangent,
    'lensEllipse': lensEllipse,
    'backdropInset': backdropInset,
    'ambientLift': ambientLift,
    'backdropReach': backdropReach,
    'bandSplitDrop': bandSplitDrop,
    'toneLumaMix': toneLumaMix,
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
    'fillColor': GlassJson.hex(fillColor),
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
      other is GlassVariantConstants &&
      GlassJson.equals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(
    toJson().values.map((v) => v is List ? Object.hashAll(v) : v),
  );
}
