import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_uniforms.dart';
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
}) => GlassFrameUniforms(
  shapes: shapes,
  devicePixelRatio: 3,
  lightAngle: -2,
  smoothing: 60,
  constants: GlassConstants.standard,
  opaqueColor: opaque,
  touch: touch,
  glow: glow,
);

void main() {
  test('layout size and header', () {
    final f = packGlassUniforms(frame([s(const Rect.fromLTWH(1, 2, 30, 40))]));
    expect(f.length, 240);
    expect(f.sublist(0, 4), [1, 3, -2, 0]);
    expect(f.sublist(4, 8), [60, GlassConstants.standard.cornerExponent, 0, 0]);
    expect(f.sublist(16, 20), [1, 2, 30, 40]);
    expect(f.sublist(80, 84), [
      10,
      0,
      GlassConstants.standard.cornerExponent,
      0,
    ]);
  });

  test('per-shape corner exponent is packed into uInfo.z', () {
    final f = packGlassUniforms(
      frame([
        s(const Rect.fromLTWH(0, 0, 10, 10), exponent: 2),
        s(const Rect.fromLTWH(20, 0, 10, 10)),
      ]),
    );
    expect(f[82], 2);
    expect(f[86], GlassConstants.standard.cornerExponent);
  });

  test('variant constants are scaled to physical px', () {
    final f = packGlassUniforms(frame(const []));
    final reg = GlassConstants.standard.regular;
    final clr = GlassConstants.standard.clear;
    expect(f.sublist(208, 212), [
      reg.lensDecay * 3,
      reg.lensBand * 3,
      reg.lensStrength,
      reg.dispersion,
    ]);
    expect(f.sublist(212, 216), [
      reg.rimWidth * 3,
      reg.rimIntensity,
      reg.fillOpacity,
      reg.dim,
    ]);
    expect(f.sublist(216, 220), [
      reg.shadowRadius * 3,
      reg.shadowOpacity,
      reg.tintStrength,
      reg.lensSizeRef * 3,
    ]);
    expect(f.sublist(232, 236), [
      clr.shadowRadius * 3,
      clr.shadowOpacity,
      clr.tintStrength,
      clr.lensSizeRef * 3,
    ]);
    expect(f.sublist(220, 224), [
      reg.fillColor.r,
      reg.fillColor.g,
      reg.fillColor.b,
      reg.saturation,
    ]);
    expect(f.sublist(224, 228), [
      clr.lensDecay * 3,
      clr.lensBand * 3,
      clr.lensStrength,
      clr.dispersion,
    ]);
    expect(f.sublist(228, 232), [
      clr.rimWidth * 3,
      clr.rimIntensity,
      clr.fillOpacity,
      clr.dim,
    ]);
    expect(f.sublist(236, 240), [
      clr.fillColor.r,
      clr.fillColor.g,
      clr.fillColor.b,
      clr.saturation,
    ]);
  });

  test('tint strength is tintStrength × alpha; clear variant index is 1', () {
    const tint = Color.fromARGB(128, 255, 0, 0);
    final f = packGlassUniforms(
      frame([
        s(const Rect.fromLTWH(0, 0, 10, 10), v: GlassVariant.clear, tint: tint),
      ]),
    );
    expect(f[81], 1);
    expect(f.sublist(144, 147), [1, 0, 0]);
    expect(
      f[147],
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

  test('count is capped at 16', () {
    final f = packGlassUniforms(
      frame(List.generate(20, (i) => s(Rect.fromLTWH(i * 10.0, 0, 5, 5)))),
    );
    expect(f[0], 16);
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
    expect(f.sublist(212, 216), [
      d.rimWidth,
      d.rimIntensity,
      d.fillOpacity,
      d.dim,
    ]);
    expect(f.sublist(220, 224), [
      d.fillColor.r,
      d.fillColor.g,
      d.fillColor.b,
      d.saturation,
    ]);
    expect(f[231], GlassConstants.standard.clearDark.dim);
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
}
