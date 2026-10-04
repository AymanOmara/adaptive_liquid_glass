import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';

/// First float index after the engine-owned `uSize` vec2.
const int kFirstUserFloat = 2;

const int _maxShapes = 16;

/// One shape for the shader, in physical px, texture space.
@immutable
class GlassShapeUniform {
  /// Creates a shape uniform.
  const GlassShapeUniform({
    required this.rect,
    required this.radius,
    required this.variant,
    this.tint,
    this.unionId,
    this.cornerExponent,
  });

  /// Shape bounds.
  final Rect rect;

  /// Corner radius.
  final double radius;

  /// Glass variant.
  final GlassVariant variant;

  /// Optional tint.
  final Color? tint;

  /// Union identity; equal ids merge into one shape.
  final Object? unionId;

  /// Superellipse exponent for this shape's corners; null uses
  /// [GlassConstants.cornerExponent]. 2 gives exact circular arcs (capsules,
  /// circles).
  final double? cornerExponent;
}

/// Everything the shader needs for one frame.
@immutable
class GlassFrameUniforms {
  /// Creates frame uniforms.
  const GlassFrameUniforms({
    required this.shapes,
    required this.devicePixelRatio,
    required this.lightAngle,
    required this.smoothing,
    required this.constants,
    this.brightness = Brightness.light,
    this.highContrast = false,
    this.opaqueColor,
    this.touch,
    this.glow = 0,
  });

  /// Light or dark appearance (selects constant sets).
  final Brightness brightness;

  /// Shapes to draw (already union-merged).
  final List<GlassShapeUniform> shapes;

  /// Physical px per logical px.
  final double devicePixelRatio;

  /// Light direction, radians, y-down.
  final double lightAngle;

  /// Smooth-min radius in physical px
  /// (`mergeFactor` × group spacing × dpr).
  final double smoothing;

  /// Rendering constants.
  final GlassConstants constants;

  /// Increase Contrast is on.
  final bool highContrast;

  /// Non-null when Reduce Transparency forces an opaque surface.
  final Color? opaqueColor;

  /// Touch point, physical px, texture space.
  final Offset? touch;

  /// Touch glow strength 0..1.
  final double glow;
}

bool _drawable(GlassShapeUniform s) =>
    s.variant != GlassVariant.identity &&
    s.rect.isFinite &&
    s.rect.width > 0 &&
    s.rect.height > 0 &&
    s.radius.isFinite;

/// Merges shapes that share a non-null `unionId` into their bounding rect,
/// keeping the smallest radius and the first shape's variant, tint and
/// corner exponent.
List<GlassShapeUniform> mergeUnions(List<GlassShapeUniform> shapes) {
  final out = <GlassShapeUniform>[];
  final byId = <Object, int>{};
  for (final s in shapes) {
    final id = s.unionId;
    final at = id == null ? null : byId[id];
    if (at == null) {
      if (id != null) byId[id] = out.length;
      out.add(s);
      continue;
    }
    final prev = out[at];
    final rect = prev.rect.expandToInclude(s.rect);
    out[at] = GlassShapeUniform(
      rect: rect,
      radius: math.min(math.min(prev.radius, s.radius), rect.shortestSide / 2),
      variant: prev.variant,
      tint: prev.tint,
      unionId: id,
      cornerExponent: prev.cornerExponent,
    );
  }
  return out;
}

/// Number of user floats after `uSize`.
const int kGlassUniformFloats = 240;

/// Packs [u] into the float layout documented in `shaders/liquid_glass.frag`:
///
/// | floats  | uniform        | contents                                  |
/// |---------|----------------|-------------------------------------------|
/// | 0–3     | uGlobal        | count, dpr, lightAngle, opaque            |
/// | 4–7     | uGlobal2       | smoothing px, cornerExponent, highContrast |
/// | 8–11    | uOpaque        | rgb                                       |
/// | 12–15   | uTouch         | x, y, glow, glowRadius px                 |
/// | 16–79   | uRects[16]     | x, y, w, h px                             |
/// | 80–143  | uInfo[16]      | radius px, clear?, cornerExponent, -      |
/// | 144–207 | uTints[16]     | rgb, strength                             |
/// | 208–239 | uVar[8]        | regular A B C D, then clear A B C D       |
///
/// Per variant: A = (blur px, lens band px, lens strength, dispersion),
/// B = (rim width px, rim intensity, fillOpacity, dim),
/// C = (shadow radius px, shadow opacity, tint strength, -),
/// D = (fill r, g, b, saturation).
List<double> packGlassUniforms(GlassFrameUniforms u) {
  final dpr = u.devicePixelRatio;
  final shapes = u.shapes.where(_drawable).take(_maxShapes).toList();
  final f = List<double>.filled(kGlassUniformFloats, 0);

  f[0] = shapes.length.toDouble();
  f[1] = dpr;
  f[2] = u.lightAngle;
  f[3] = u.opaqueColor == null ? 0 : 1;

  f[4] = u.smoothing;
  f[5] = u.constants.cornerExponent;
  f[6] = u.highContrast ? 1 : 0;

  final o = u.opaqueColor;
  if (o != null) {
    f[8] = o.r;
    f[9] = o.g;
    f[10] = o.b;
  }

  final t = u.touch;
  if (t != null) {
    f[12] = t.dx;
    f[13] = t.dy;
    f[14] = u.glow;
  }
  f[15] = u.constants.motion.glowRadius * dpr;

  for (var i = 0; i < shapes.length; i++) {
    final s = shapes[i];
    final v = u.constants.of(s.variant, u.brightness);
    f.setAll(16 + i * 4, [
      s.rect.left,
      s.rect.top,
      s.rect.width,
      s.rect.height,
    ]);
    f.setAll(80 + i * 4, [
      s.radius,
      s.variant == GlassVariant.clear ? 1 : 0,
      s.cornerExponent ?? u.constants.cornerExponent,
      0,
    ]);
    final tint = s.tint;
    if (tint != null) {
      f.setAll(144 + i * 4, [tint.r, tint.g, tint.b, v.tintStrength * tint.a]);
    }
  }

  var k = 208;
  for (final v in [
    u.constants.of(GlassVariant.regular, u.brightness),
    u.constants.of(GlassVariant.clear, u.brightness),
  ]) {
    f.setAll(k, [
      v.blurSigma * dpr,
      v.lensBand * dpr,
      v.lensStrength,
      v.dispersion,
    ]);
    f.setAll(k + 4, [v.rimWidth * dpr, v.rimIntensity, v.fillOpacity, v.dim]);
    f.setAll(k + 8, [v.shadowRadius * dpr, v.shadowOpacity, v.tintStrength, 0]);
    f.setAll(k + 12, [
      v.fillColor.r,
      v.fillColor.g,
      v.fillColor.b,
      v.saturation,
    ]);
    k += 16;
  }
  return f;
}
