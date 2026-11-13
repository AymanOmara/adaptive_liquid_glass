import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../core/glass.dart';
import '../core/glass_shape.dart';
import '../core/glass_transition.dart';
import 'glass_press_geometry.dart';
import 'render_glass_content_fill.dart';
import 'render_glass_content_glyphs.dart';

/// One `LiquidGlass` registered with a group.
class GlassEntry {
  /// Creates an entry.
  GlassEntry({
    required this.shape,
    required this.glass,
    this.glassId,
    this.unionId,
    this.transition = GlassTransition.matchedGeometry,
  });

  /// Shape of the glass.
  GlassShape shape;

  /// Glass material.
  Glass glass;

  /// Morph identity (`glassEffectID`).
  Object? glassId;

  /// Union identity (`glassEffectUnion`).
  Object? unionId;

  /// How this entry appears and goes (`glassEffectTransition`).
  GlassTransition transition;

  /// What the morph controller tracks this entry by; null when it does not
  /// animate. A `glassId` names the track, and so does the entry itself
  /// for an in-place `materialize`.
  Object? get morphKey => switch (transition) {
    GlassTransition.identity => null,
    GlassTransition.matchedGeometry => glassId,
    GlassTransition.materialize => glassId ?? this,
  };

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

  /// System fills inside this glass that native glass draws as its own
  /// content (see GlassContentFill).
  final Set<RenderGlassContentFill> fills = <RenderGlassContentFill>{};

  /// Glyph masks inside this glass that native glass fills as its own
  /// content (see GlassContentGlyphs).
  final Set<RenderGlassContentGlyphs> glyphs = <RenderGlassContentGlyphs>{};

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
