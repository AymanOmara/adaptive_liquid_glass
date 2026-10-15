import 'dart:math' as math;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_frame_uniforms.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_shape_uniform.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GlassShapeUniform s(
  Rect r, {
  double radius = 10,
  GlassVariant v = GlassVariant.regular,
  Color? tint,
  Object? union,
  double? exponent,
}) => GlassShapeUniform(
  rect: r,
  radius: radius,
  variant: v,
  tint: tint,
  unionId: union,
  cornerExponent: exponent,
);

GlassFrameUniforms frame(
  List<GlassShapeUniform> shapes, {
  Color? opaque,
  Offset? touch,
  double glow = 0,
  GlassConstants constants = GlassConstants.standard,
}) => GlassFrameUniforms(
  shapes: shapes,
  devicePixelRatio: 3,
  lightAngle: -2,
  smoothing: 60,
  constants: constants,
  opaqueColor: opaque,
  touch: touch,
  glow: glow,
);

void main() {
  test('layout size and header', () {
    final f = packGlassUniforms(
      frame(
        [s(const Rect.fromLTWH(1, 2, 30, 40))],
        constants: GlassConstants.fromJson({
          'regular': {'fillSizeRef': 0.0},
        }),
      ),
    );
    expect(f.length, 640);
    expect(f.sublist(0, 4), [1, 3, -2, 0]);
    expect(f.sublist(4, 8), [
      60,
      GlassConstants.standard.cornerExponent,
      0,
      GlassConstants.standard.cornerZone,
    ]);
    expect(f.sublist(16, 20), [1, 2, 30, 40]);
    expect(f.sublist(112, 116), [
      10,
      0,
      0, // global exponent (uGlobal2.y) + continuous-corner zone
      1, // fill scale: fillSizeRef 0 disables size scaling
    ]);
  });

  test('per-shape fill scale in uInfo.w follows fillSizeRef/fillSizeDrop', () {
    final c = GlassConstants.fromJson({
      'regular': {'fillSizeRef': 40.0, 'fillSizeDrop': 0.2},
      'clear': {'fillSizeRef': 0.0, 'fillSizeDrop': 0.5},
    });
    final f = packGlassUniforms(
      frame(constants: c, [
        // 60 x 120 px at dpr 3: half the shorter side 10 pt -> 1 - 0.2 x 0.75.
        s(const Rect.fromLTWH(0, 0, 60, 120)),
        // Half side 50 pt >= 40: unscaled.
        s(const Rect.fromLTWH(0, 0, 300, 600)),
        // fillSizeRef 0 disables the scaling.
        s(const Rect.fromLTWH(0, 0, 60, 60), v: GlassVariant.clear),
      ]),
    );
    expect(f[115], closeTo(0.85, 1e-9));
    expect(f[119], 1);
    expect(f[123], 1);
  });

  test('per-shape corner exponent is packed into uInfo.z', () {
    final f = packGlassUniforms(
      frame([
        s(const Rect.fromLTWH(0, 0, 10, 10), exponent: 2),
        s(const Rect.fromLTWH(20, 0, 10, 10)),
      ]),
    );
    expect(f[114], 2);
    expect(f[118], 0); // global exponent + continuous-corner zone
  });

  test('variant constants are scaled to physical px', () {
    final f = packGlassUniforms(frame(const []));
    final reg = GlassConstants.standard.regular;
    final clr = GlassConstants.standard.clear;
    expect(f.sublist(304, 308), [
      reg.lensDecay * 3,
      reg.lensBand * 3,
      reg.lensStrength,
      reg.dispersion,
    ]);
    expect(f.sublist(308, 312), [
      reg.rimWidth * 3,
      reg.rimIntensity,
      reg.fillOpacity,
      reg.dim,
    ]);
    expect(f.sublist(312, 316), [
      reg.shadowRadius * 3,
      reg.shadowOpacity,
      reg.tintStrength,
      reg.lensSizeRef * 3,
    ]);
    expect(f.sublist(360, 364), [
      clr.shadowRadius * 3,
      clr.shadowOpacity,
      clr.tintStrength,
      clr.lensSizeRef * 3,
    ]);
    expect(f.sublist(316, 320), [
      reg.fillColor.r,
      reg.fillColor.g,
      reg.fillColor.b,
      reg.saturation,
    ]);
    expect(f.sublist(352, 356), [
      clr.lensDecay * 3,
      clr.lensBand * 3,
      clr.lensStrength,
      clr.dispersion,
    ]);
    expect(f.sublist(356, 360), [
      clr.rimWidth * 3,
      clr.rimIntensity,
      clr.fillOpacity,
      clr.dim,
    ]);
    expect(f.sublist(364, 368), [
      clr.fillColor.r,
      clr.fillColor.g,
      clr.fillColor.b,
      clr.saturation,
    ]);
  });

  test('frost v2 constants pack into E and F (physical px)', () {
    final c = GlassConstants.fromJson({
      'regular': {
        'frostWideSigma': 5.5,
        'frostWideMixEdge': 0.3,
        'frostWideMixCentre': 1.2,
        'frostWideSizeRef': 70.0,
        'frostWideSizeDrop': 1.4,
      },
      'clear': {
        'frostWideSigma': 4.0,
        'frostWideMixEdge': -0.1,
        'frostWideMixCentre': 0.2,
        'frostWideSizeRef': 0.0,
        'frostWideSizeDrop': 0.5,
      },
    });
    final f = packGlassUniforms(frame(const [], constants: c));
    expect(f.sublist(320, 324), [5.5 * 3, 0.3, 1.2, 70 * 3]);
    expect(f[324], 1.4);
    expect(f.sublist(368, 372), [4.0 * 3, -0.1, 0.2, 0]);
    expect(f[372], 0.5);
  });

  test('tone LUT knots pack into G, H and I (standard when absent)', () {
    final std = packGlassUniforms(frame(const []));
    // Since the g13 refit the shipped regular set carries fitted knots;
    // fromJson fills absent keys from standard, so the pack carries them.
    final reg = GlassConstants.standard.regular.toneKnots;
    expect(std.sublist(328, 332), reg.sublist(0, 4));
    expect(std.sublist(332, 336), reg.sublist(4, 8));
    expect(std[336], reg[8]);
    // The clear set's knots live 48 floats later.
    expect(std[336 + 48], GlassConstants.standard.clear.toneKnots[8]);

    final c = GlassConstants.fromJson({
      'regular': {
        'toneKnots': [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
      },
    });
    final f = packGlassUniforms(frame(const [], constants: c));
    expect(f.sublist(328, 332), [0.0, 0.1, 0.2, 0.3]);
    expect(f.sublist(332, 336), [0.4, 0.5, 0.6, 0.7]);
    expect(f[336], 0.8);
  });

  test('Task 17d keys pack into F, I and J (pre-17d behaviour by default)', () {
    final d = packGlassUniforms(frame(const []));
    // F.yzw: the fitted glow, no post-lens blur, outline normals.
    expect(d.sublist(325, 328), [closeTo(0.027, 1e-6), 0, 1]);
    expect(d.sublist(337, 340), [0, closeTo(0.6 * 3, 1e-12), 0]);
    expect(d.sublist(344, 347), [0.5, 0, 0]); // K.w = blurSizeRef·dpr
    expect(d.sublist(340, 344), [0, 1.5 * 3, 1 * 3, 1]);
    expect(d[7], GlassConstants.standard.cornerZone); // uGlobal2.w (Task A1)
    expect([d[348], d[396]], [0.35, 0.35]); // L.x rimBack

    final c = GlassConstants.fromJson({
      'clear': {
        'glowStrength': 0.4,
        'postBlurShare': 0.95, // clamped to 0.9
        'normalRadiusScale': 1.55,
        'lensEdge': 9.0,
        'lensEdgeDecay': 0.6,
        'rimMix': 0.63,
        'rimMixWidth': 1.5,
        'rimMixCut': 1.0,
        'rimMixLumaFloor': 0.05,
      },
    });
    final f = packGlassUniforms(
      GlassFrameUniforms(
        shapes: const [],
        devicePixelRatio: 3,
        lightAngle: 0,
        smoothing: 0,
        constants: c,
      ),
    );
    expect(f[7], c.cornerZone);
    // K.zw: post-lens sigma = blurSigma·√0.9·dpr, blur size ref·dpr.
    expect(f[394], closeTo(c.clear.blurSigma * math.sqrt(0.9) * 3, 1e-12));
    expect(f[395], c.clear.blurSizeRef * 3);
    expect(f.sublist(373, 376), [0.4, 0.9, 1.55]);
    expect(f.sublist(385, 388), [9.0 * 3, closeTo(0.6 * 3, 1e-12), 0]);
    expect(f.sublist(388, 392), [0.63, 1.5 * 3, 1.0 * 3, 0.05]);
  });

  test('toneLift keys pack into I.w and K.xy (size ref × dpr)', () {
    final c = GlassConstants.fromJson({
      'regularDark': {
        'toneLift': 0.7,
        'toneLiftKnee': 0.8,
        'toneLiftSizeRef': 48.0,
      },
    });
    final f = packGlassUniforms(
      GlassFrameUniforms(
        shapes: const [],
        devicePixelRatio: 2,
        lightAngle: 0,
        smoothing: 0,
        constants: c,
        brightness: Brightness.dark,
      ),
    );
    expect(f[339], 0.7); // regular I.w
    expect(f.sublist(344, 346), [0.8, 48.0 * 2]); // regular K.xy
    expect(f[387], 0); // clear I.w: lift off
  });

  test(
    'mixed regular + clear group: each variant keeps its own post sigma',
    () {
      final c = GlassConstants.fromJson({
        'regular': {
          'blurSigma': 6.0,
          'postBlurShare': 0.0,
          'blurSizeRef': 60.0,
        },
        'clear': {'blurSigma': 1.2, 'postBlurShare': 0.36, 'blurSizeRef': 0.0},
      });
      final f = packGlassUniforms(
        frame([
          s(const Rect.fromLTWH(0, 0, 300, 300)),
          s(const Rect.fromLTWH(0, 400, 60, 60), v: GlassVariant.clear),
        ], constants: c),
      );
      // regular K.zw: no post blur; clear K.zw: 1.2·0.6·3 px, no size scale.
      expect(f.sublist(346, 348), [0, 60.0 * 3]);
      expect(f[394], closeTo(1.2 * 0.6 * 3, 1e-12));
      expect(f[395], 0);
    },
  );

  test('composed blur aspect follows (h / w) ^ blurAspectPower', () {
    final v = GlassConstants.fromJson({
      'regular': {'blurAspectPower': 0.5},
    }).regular;
    expect(composedBlurAspect(v, const Size(200, 50)), closeTo(0.5, 1e-12));
    expect(composedBlurAspect(v, const Size(60, 60)), 1);
    expect(
      composedBlurAspect(GlassConstants.standard.regular, const Size(200, 50)),
      1,
    );
  });

  test('composed blur sigma scales by size and post-lens share', () {
    const v = GlassVariantConstants(
      blurSigma: 4,
      blurSizeRef: 40,
      postBlurShare: 0.36,
      lensBand: 1,
      lensStrength: 0,
      lensDecay: 1,
      lensSizeRef: 0,
      dispersion: 0,
      rimWidth: 1,
      rimIntensity: 0,
      fillColor: Color(0xFFFFFFFF),
      fillOpacity: 0,
      saturation: 1,
      dim: 0,
      shadowRadius: 0,
      shadowOpacity: 0,
      tintStrength: 0,
    );
    expect(composedBlurSigma(v, 20), closeTo(4 * 0.5 * 0.8, 1e-12));
    expect(composedBlurSigma(v, 80), closeTo(4 * 0.8, 1e-12));
  });
  test('tint strength is tintStrength × alpha; clear variant index is 1', () {
    const tint = Color.fromARGB(128, 255, 0, 0);
    final f = packGlassUniforms(
      frame([
        s(const Rect.fromLTWH(0, 0, 10, 10), v: GlassVariant.clear, tint: tint),
      ]),
    );
    expect(f[113], 1);
    expect(f.sublist(208, 211), [1, 0, 0]);
    expect(
      f[211],
      closeTo(GlassConstants.standard.clear.tintStrength * tint.a, 1e-9),
    );
  });

  test('empty, non-finite and identity shapes are skipped', () {
    final f = packGlassUniforms(
      frame([
        s(Rect.zero),
        s(const Rect.fromLTWH(0, 0, double.nan, 5)),
        s(const Rect.fromLTWH(0, 0, 5, 5), v: GlassVariant.identity),
        s(const Rect.fromLTWH(5, 6, 7, 8)),
      ]),
    );
    expect(f[0], 1);
    expect(f.sublist(16, 20), [5, 6, 7, 8]);
    expect(f.every((x) => x.isFinite), isTrue);
  });

  test('per-group defaults: group 0, frame smoothing, opacity 1, no clip', () {
    final f = packGlassUniforms(
      frame([s(const Rect.fromLTWH(1, 2, 30, 40)), s(Rect.zero)]),
    );
    expect(f.sublist(kExtraAt, kExtraAt + 4), [0, 60, 1, 0]);
    expect(f.sublist(kClipAt, kClipAt + 4), [-1e9, -1e9, 1e9, 1e9]);
  });

  test('shared-layer group, smoothing, opacity and clip pack per shape', () {
    final a = s(const Rect.fromLTWH(1, 2, 30, 40));
    final b = s(const Rect.fromLTWH(100, 2, 30, 40)).inGroup(
      group: 1,
      smoothing: 12,
      opacity: 0.5,
      clip: const Rect.fromLTRB(0, 10, 200, 300),
    );
    final f = packGlassUniforms(frame([a, b]));
    expect(f.sublist(kExtraAt + 4, kExtraAt + 8), [1, 12, 0.5, 0]);
    expect(f.sublist(kClipAt + 4, kClipAt + 8), [0, 10, 200, 300]);
    expect(f.sublist(kRectsAt + 4, kRectsAt + 8), [100, 2, 30, 40]);
  });

  test('mergeUnions keeps the group fields', () {
    const clip = Rect.fromLTRB(0, 0, 50, 50);
    final merged = mergeUnions([
      s(
        const Rect.fromLTWH(0, 0, 10, 10),
        union: 'u',
      ).inGroup(group: 2, smoothing: 3, opacity: 0.4, clip: clip),
      s(const Rect.fromLTWH(20, 0, 10, 10), union: 'u'),
    ]);
    expect(merged.single.group, 2);
    expect(merged.single.smoothing, 3);
    expect(merged.single.opacity, 0.4);
    expect(merged.single.clip, clip);
  });

  test('count is capped at 24', () {
    final f = packGlassUniforms(
      frame(List.generate(30, (i) => s(Rect.fromLTWH(i * 10.0, 0, 5, 5)))),
    );
    expect(f[0], 24);
  });

  test('dark brightness packs the dark constant sets', () {
    final f = packGlassUniforms(
      const GlassFrameUniforms(
        shapes: [],
        devicePixelRatio: 1,
        lightAngle: 0,
        smoothing: 0,
        constants: GlassConstants.standard,
        brightness: Brightness.dark,
      ),
    );
    final d = GlassConstants.standard.regularDark;
    expect(f.sublist(308, 312), [
      d.rimWidth,
      d.rimIntensity,
      d.fillOpacity,
      d.dim,
    ]);
    expect(f.sublist(316, 320), [
      d.fillColor.r,
      d.fillColor.g,
      d.fillColor.b,
      d.saturation,
    ]);
    expect(f[359], GlassConstants.standard.clearDark.dim);
  });

  test('opaque and touch', () {
    final f = packGlassUniforms(
      frame(
        const [],
        opaque: const Color(0xFF00FF00),
        touch: const Offset(7, 9),
        glow: 0.5,
      ),
    );
    expect(f[3], 1);
    expect(f.sublist(8, 11), [0, 1, 0]);
    expect(f.sublist(12, 15), [7, 9, 0.5]);
    expect(f[15], GlassConstants.standard.motion.glowRadius * 3);
  });

  test('mergeUnions joins same-id shapes into their bounding rect', () {
    final out = mergeUnions([
      s(const Rect.fromLTWH(0, 0, 40, 40), radius: 20, union: 'a'),
      s(const Rect.fromLTWH(100, 0, 40, 40), radius: 12, union: 'a'),
      s(const Rect.fromLTWH(0, 100, 10, 10)),
    ]);
    expect(out, hasLength(2));
    expect(out.first.rect, const Rect.fromLTWH(0, 0, 140, 40));
    expect(out.first.radius, 12);
    expect(out.last.rect, const Rect.fromLTWH(0, 100, 10, 10));
  });

  test('mergeUnions keeps the first shape\'s corner exponent', () {
    final out = mergeUnions([
      s(const Rect.fromLTWH(0, 0, 40, 40), union: 'a', exponent: 2),
      s(const Rect.fromLTWH(100, 0, 40, 40), union: 'a'),
    ]);
    expect(out.single.cornerExponent, 2);
  });

  test('small-shape tone curve packs into M, N and O (on for regular)', () {
    final d = packGlassUniforms(frame(const []));
    // The g13 refit ships the curve on regular/regularDark; clear keeps
    // the identity knots and a closed size window.
    final reg = GlassConstants.standard.regular;
    expect(d.sublist(400, 404), reg.smallToneKnots.sublist(0, 4));
    expect(d.sublist(404, 408), reg.smallToneKnots.sublist(4, 8));
    expect(d.sublist(408, 412), [
      reg.smallToneKnots[8],
      reg.smallSizeLo * 3,
      reg.smallSizeHi * 3,
      reg.postJacobianMax,
    ]);
    // The clear set 48 floats later stays identity/off; O.w carries the
    // clear post-lens Jacobian clamp (fidelity group 4).
    expect(
      d.sublist(412, 416),
      GlassVariantConstants.identityToneKnots.sublist(0, 4),
    );
    expect(d.sublist(420, 424), [1.0, 0, 0, 1.15]);

    final c = GlassConstants.fromJson({
      'regular': {
        'smallToneKnots': [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8],
        'smallSizeLo': 30.0,
        'smallSizeHi': 34.0,
      },
    });
    final f = packGlassUniforms(frame(const [], constants: c));
    expect(f.sublist(400, 404), [0.0, 0.1, 0.2, 0.3]);
    expect(f.sublist(404, 408), [0.4, 0.5, 0.6, 0.7]);
    // O = (knot 8, smallSizeLo px, smallSizeHi px, postJacobianMax).
    expect(f.sublist(408, 412), [0.8, 30 * 3, 34 * 3, 4]);
    // The clear set keeps the identity defaults (N.x = knot 4).
    expect(f[416], 0.5);
    expect(f[420], 1.0);
    expect(f.sublist(421, 424), [0, 0, 1.15]);
  });

  test('sideways dispersion and elliptical normals pack into Q after P', () {
    final c = GlassConstants.fromJson({
      'regular': {
        'dispersionTangent': 0.5,
        'lensEllipse': 1.0,
        'backdropInset': 4.0,
        'ambientLift': 0.5,
        'backdropReach': 1.0,
        'bandSplitDrop': 0.5,
      },
      'clear': {'dispersionTangent': -3.0},
    });
    final f = packGlassUniforms(frame(const [], constants: c));
    // The inset is a length (x dpr 3).
    expect(f.sublist(432, 436), [0.5, 1, 12, 0.5]);
    expect(f.sublist(436, 440), [-3, 0, 0, 0]);
    expect(f.sublist(440, 444), [3, 0.5, 0, 0]);
  });

  test('ambient colour packs into P after the M-O blocks (item 8)', () {
    final c = GlassConstants.fromJson({
      'regular': {'ambientMix': 0.25, 'ambientReach': 12.0, 'toneLumaMix': 0.5},
      'clear': {'ambientMix': 0.0, 'ambientReach': 0.0},
    });
    final f = packGlassUniforms(frame(const [], constants: c));
    // Reach is a length (x dpr 3); the mix is a weight.
    expect(f.sublist(424, 428), [0.25, 36, 0.5, 0]);
    expect(f.sublist(428, 432), [0, 0, 0, 0]);
    final d = packGlassUniforms(frame(const []));
    final reg = GlassConstants.standard.regular;
    expect(d.sublist(424, 428), [
      reg.ambientMix,
      reg.ambientReach * 3,
      reg.toneLumaMix,
      0,
    ]);
  });

  test('lensVertical and the rim tint pack into L.yzw (off by default)', () {
    final d = packGlassUniforms(frame(const []));
    expect(d.sublist(349, 352), [0, 0, 0]);
    expect(d.sublist(397, 400), [0, 0, 0]);
    final c = GlassConstants.fromJson({
      'clear': {'lensVertical': 1.0, 'rimTint': 0.5, 'rimHue': 180.0},
    });
    final f = packGlassUniforms(frame(const [], constants: c));
    // Weights, not lengths: no dpr scaling; the hue in turns. Clear
    // variant's L at 300.
    expect(f.sublist(397, 400), [1.0, 0.5, 0.5]);
    expect(f.sublist(349, 352), [0, 0, 0]);
  });
}
