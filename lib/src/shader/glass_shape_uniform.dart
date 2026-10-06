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
