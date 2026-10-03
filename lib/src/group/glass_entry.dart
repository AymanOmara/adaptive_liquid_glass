import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';

/// Press deformation of one member, produced by the press controller.
@immutable
class GlassPressGeometry {
  /// Creates a press geometry.
  const GlassPressGeometry({
    this.scaleX = 1,
    this.scaleY = 1,
    this.translation = Offset.zero,
    this.glow = 0,
    this.touch,
  });

  /// No deformation.
  static const GlassPressGeometry identity = GlassPressGeometry();

  /// Horizontal scale about the shape centre.
  final double scaleX;

  /// Vertical scale about the shape centre.
  final double scaleY;

  /// Offset of the shape centre, logical px.
  final Offset translation;

  /// Touch glow strength, 0..1.
  final double glow;

  /// Touch point in the member's local coordinates.
  final Offset? touch;

  /// [r] deformed by this geometry.
  Rect apply(Rect r) => Rect.fromCenter(
    center: r.center + translation,
    width: r.width * scaleX,
    height: r.height * scaleY,
  );

  /// Corner radii scale with the smaller axis scale.
  double get radiusScale => math.min(scaleX, scaleY);
}

/// One `LiquidGlass` registered with a group.
class GlassEntry {
  /// Creates an entry.
  GlassEntry({
    required this.shape,
    required this.glass,
    this.glassId,
    this.unionId,
  });

  /// Shape of the glass.
  GlassShape shape;

  /// Glass material.
  Glass glass;

  /// Morph identity (`glassEffectID`).
  Object? glassId;

  /// Union identity (`glassEffectUnion`).
  Object? unionId;

  /// The member's render box; set when its render object is created.
  RenderBox? box;

  /// Current press deformation.
  GlassPressGeometry press = GlassPressGeometry.identity;

  /// While morphing: the rect to draw, in the group's local coordinates.
  Rect? morphRect;

  /// The enclosing glass, for `GlassShape.concentric`.
  GlassEntry? container;

  /// Whether [box] is attached and has a non-empty size.
  bool get isLaidOut {
    final b = box;
    return b != null && b.attached && b.hasSize && !b.size.isEmpty;
  }
}
