import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';
import 'glass_entry.dart';
import 'glass_registry.dart';

/// One entry's resolved geometry in global logical coordinates.
@immutable
class EntryGeometry {
  /// Creates geometry.
  const EntryGeometry(this.entry, this.base, this.drawn, this.radius);

  /// The entry.
  final GlassEntry entry;

  /// Rect before press deformation.
  final Rect base;

  /// Rect as drawn (press applied).
  final Rect drawn;

  /// Corner radius as drawn.
  final double radius;
}

/// Drawable entries of [registry], laid-out members and ghosts alike.
///
/// [groupToGlobal] converts morph rects, which are local to the group's
/// renderer, to global coordinates.
List<EntryGeometry> collectEntryGeometry(
  GlassRegistry registry,
  Matrix4 groupToGlobal,
) {
  final out = <EntryGeometry>[];
  for (final e in registry.entries) {
    if (!(e.isLaidOut || e.isGhost) ||
        e.glass.variant == GlassVariant.identity) {
      continue;
    }
    // A morphing or ghost entry draws its group-local `morphRect`.
    final morph = e.morphRect;
    final Rect base;
    if (morph != null) {
      base = MatrixUtils.transformRect(groupToGlobal, morph);
    } else {
      final box = e.box!;
      base = MatrixUtils.transformRect(
        box.getTransformTo(null),
        e.shape.resolveRect(box.size),
      );
    }
    if (!base.isFinite || base.isEmpty) continue;

    double? concentric;
    final shape = e.shape;
    final c = e.container;
    if (shape is ConcentricGlassShape && c != null && c.isLaidOut) {
      final cBox = c.box!;
      concentric = concentricRadius(
        container: MatrixUtils.transformRect(
          cBox.getTransformTo(null),
          c.shape.resolveRect(cBox.size),
        ),
        containerRadius: c.shape.resolveRadius(cBox.size),
        child: base,
        minimum: shape.minimum,
      );
    }
    final radius =
        shape.resolveRadius(base.size, concentricRadius: concentric) *
        e.press.radiusScale;
    out.add(EntryGeometry(e, base, e.press.apply(base), radius));
  }
  return out;
}
