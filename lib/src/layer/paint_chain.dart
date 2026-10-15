import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// How a render object's ancestors paint it, up to (not including) the
/// first ancestor in a stop set: what the shared glass layer must redo
/// when it paints a group's glass and content somewhere else.
@immutable
class PaintChain {
  /// Creates a chain.
  const PaintChain({
    required this.painted,
    required this.opacity,
    required this.clip,
    required this.order,
  });

  /// Whether every ancestor paints the next one (`paintsChild`): false
  /// under `Offstage`, a zero opacity, a hidden `IndexedStack` child.
  final bool painted;

  /// Product of the `Opacity`/`FadeTransition` ancestors.
  final double opacity;

  /// Intersection of the ancestors' approximate paint clips, global logical
  /// px; null when nothing clips.
  final Rect? clip;

  /// Child index at each level, from the stop ancestor down: paint order
  /// when compared lexicographically.
  final List<int> order;
}

double? _opacityOf(RenderObject o) => switch (o) {
  RenderOpacity(:final opacity) => opacity,
  RenderSliverOpacity(:final opacity) => opacity,
  RenderAnimatedOpacityMixin(:final opacity) => opacity.value,
  _ => null,
};

/// `RenderIndexedStack` paints only its selected child but does not say
/// so through `paintsChild`; its semantics visit only that child.
bool _indexedStackShows(RenderObject parent, RenderObject child) {
  if (parent is! RenderIndexedStack) return true;
  var shown = false;
  parent.visitChildrenForSemantics((c) {
    if (identical(c, child)) shown = true;
  });
  return shown;
}

int _indexOf(RenderObject parent, RenderObject child) {
  var i = 0;
  var found = -1;
  parent.visitChildren((c) {
    if (identical(c, child)) found = i;
    i++;
  });
  return found;
}

/// The ancestors of [node] (the node excluded), nearest first, up to the
/// root.
List<RenderObject> ancestorsOf(RenderObject node) {
  final out = <RenderObject>[];
  for (var p = node.parent; p != null; p = p.parent) {
    out.add(p);
  }
  return out;
}

/// Walks from [node] up to the first ancestor in [stopAt] (or the root).
PaintChain describePaintChain(RenderObject node, Set<RenderObject> stopAt) {
  var painted = true;
  var opacity = 1.0;
  Rect? clip;
  final order = <int>[];
  RenderObject child = node;
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    order.add(_indexOf(parent, child));
    if (stopAt.contains(parent)) break;
    if (!parent.paintsChild(child) || !_indexedStackShows(parent, child)) {
      painted = false;
    }
    final a = _opacityOf(parent);
    if (a != null) opacity *= a;
    final c = parent.describeApproximatePaintClip(child);
    if (c != null) {
      final global = MatrixUtils.transformRect(parent.getTransformTo(null), c);
      clip = clip == null ? global : clip.intersect(global);
    }
    child = parent;
  }
  return PaintChain(
    painted: painted,
    opacity: opacity,
    clip: clip,
    order: order.reversed.toList(),
  );
}
