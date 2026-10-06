import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';
import 'glass_press_geometry.dart';

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

  /// Where the renderer last drew this entry, in group-local coordinates.
  Rect? lastDrawnLocal;

  /// Content opacity during morphs.
  final ValueNotifier<double> contentOpacity = ValueNotifier(1);

  /// A removed member still animating out.
  bool get isGhost => box == null && morphRect != null;

  /// Whether [box] is attached and has a non-empty size.
  bool get isLaidOut {
    final b = box;
    return b != null && b.attached && b.hasSize && !b.size.isEmpty;
  }
}
