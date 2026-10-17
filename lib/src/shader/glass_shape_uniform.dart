import 'package:flutter/material.dart';

import '../core/glass_constants.dart';
import '../core/glass_variant.dart';

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
    this.group = 0,
    this.smoothing,
    this.opacity = 1,
    this.clip,
    this.light = 0,
    this.blurSigma = 0,
    this.blurAspect = 1,
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

  /// Index of the shape's glass group within a shared-layer pass; shapes of
  /// one group are packed together, smooth-union only among themselves and
  /// never merge with another group's.
  final int group;

  /// The group's smooth-union radius (physical px); null uses
  /// `GlassFrameUniforms.smoothing`.
  final double? smoothing;

  /// The group's opacity (ancestor `Opacity`/`FadeTransition` on the shared
  /// layer); 1 on the per-group path.
  final double opacity;

  /// The group's clip in texture space (physical px); null is unbounded.
  final Rect? clip;

  /// SwiftUI's press light on this shape, 0..1
  /// (`GlassPressGeometry.light`): a lift over the whole shape.
  final double light;

  /// The frost this shape wants (`composedBlurSigma`, logical px); the
  /// shader adds what the pass's blur lacks. 0 asks for none beyond it.
  final double blurSigma;

  /// sigmaX / [blurSigma] (`composedBlurAspect`).
  final double blurAspect;

  /// A copy with the shared-layer fields replaced.
  GlassShapeUniform inGroup({
    required int group,
    required double smoothing,
    double opacity = 1,
    Rect? clip,
  }) => GlassShapeUniform(
    rect: rect,
    radius: radius,
    variant: variant,
    tint: tint,
    unionId: unionId,
    cornerExponent: cornerExponent,
    group: group,
    smoothing: smoothing,
    opacity: opacity,
    clip: clip,
    light: light,
    blurSigma: blurSigma,
    blurAspect: blurAspect,
  );
}
