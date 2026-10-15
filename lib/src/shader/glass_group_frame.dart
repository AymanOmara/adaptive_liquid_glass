import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../group/entry_geometry.dart';
import '../group/glass_registry.dart';
import 'glass_backdrop_config.dart';
import 'glass_backdrop_debug_frame.dart';
import 'glass_frame_uniforms.dart';
import 'glass_shape_uniform.dart';
import 'glass_texture_space.dart';

/// One glass group's frame: its shapes in texture space, the clip bounds in
/// the group's local space, the composed blur and the touch glow. Null when
/// nothing is drawable. Records each entry's `lastDrawnLocal` (morph ghosts).
///
/// [toGlobal] is the group renderer's transform to the screen. Shared by the
/// per-group backdrop and the shared glass layer.
GlassBackdropDebugFrame? computeGroupFrame({
  required GlassRegistry registry,
  required GlassBackdropConfig config,
  required Matrix4 toGlobal,
}) {
  final dpr = config.devicePixelRatio;
  final fromGlobal = Matrix4.tryInvert(toGlobal);
  if (fromGlobal == null) return null;

  final drawn = collectEntryGeometry(registry, toGlobal);
  for (final g in drawn) {
    g.entry.lastDrawnLocal = MatrixUtils.transformRect(fromGlobal, g.drawn);
  }
  if (drawn.isEmpty) return null;

  final union = drawn
      .map((g) => g.drawn)
      .reduce((a, b) => a.expandToInclude(b));
  final c = config.constants;
  final shadow = [
    c.regular,
    c.clear,
    c.regularDark,
    c.clearDark,
  ].map((v) => v.shadowRadius).reduce(math.max);
  // The smooth union bulges up to mergeFactor × spacing past the shapes.
  final margin = shadow * 2 + math.max(1.0, c.mergeFactor) * config.spacing + 2;
  final localBounds = MatrixUtils.transformRect(
    fromGlobal,
    union,
  ).inflate(margin);
  final origin = MatrixUtils.transformPoint(toGlobal, localBounds.topLeft);

  final shapes = mergeUnions([
    for (final g in drawn)
      GlassShapeUniform(
        rect: toTextureSpace(
          g.drawn,
          filterOriginGlobal: origin,
          devicePixelRatio: dpr,
        ),
        radius: g.radius * dpr,
        variant: g.entry.glass.variant,
        tint: g.entry.glass.tintColor,
        unionId: g.entry.unionId,
        cornerExponent: g.circularCorners ? 2.0 : null,
      ),
  ]);

  // One blur per group: the largest of the drawn shapes' sigmas, each
  // scaled down on shapes smaller than blurSizeRef and by the post-lens
  // share. Known limitation: a group mixing regular and clear (or large
  // and small) glass blurs every member as strongly as the strongest one.
  // The strongest member also sets the blur's aspect (blurAspectPower).
  var blurSigma = -1.0;
  var blurAspect = 1.0;
  for (final g in drawn) {
    final v = c.of(g.entry.glass.variant, config.brightness);
    final s = composedBlurSigma(v, g.drawn.shortestSide / 2);
    if (s > blurSigma) {
      blurSigma = s;
      blurAspect = composedBlurAspect(v, g.drawn.size);
    }
  }

  Offset? touch;
  var glow = 0.0;
  for (final g in drawn) {
    final e = g.entry;
    final p = e.press.touch;
    final box = e.box;
    if (box == null) continue; // ghosts have no touch
    if (p != null && e.press.glow > glow) {
      glow = e.press.glow;
      touch = pointToTextureSpace(
        MatrixUtils.transformPoint(box.getTransformTo(null), p),
        filterOriginGlobal: origin,
        devicePixelRatio: dpr,
      );
    }
  }

  return GlassBackdropDebugFrame(
    GlassFrameUniforms(
      shapes: shapes,
      devicePixelRatio: dpr,
      lightAngle: config.lightAngle,
      // Smooth-union radius: mergeFactor × spacing (physical px).
      smoothing: c.mergeFactor * config.spacing * dpr,
      constants: c,
      brightness: config.brightness,
      highContrast: config.highContrast,
      opaqueColor: config.opaqueColor,
      touch: touch,
      glow: glow,
    ),
    localBounds,
    origin,
    blurSigma,
    blurAspect,
  );
}
