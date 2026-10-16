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
    this.clipPath,
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

  /// Intersection of the ancestors' clips that are not plain rectangles
  /// (`ClipRRect`, `ClipRSuperellipse`, `ClipOval`, `ClipPath`, a
  /// `PhysicalModel`'s shape), global logical px; null when every clip is a
  /// rectangle. [clip] bounds it.
  final Path? clipPath;

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

/// [parent]'s clip of its children in its own coordinates when it is not
/// a plain rectangle; null otherwise.
Path? _shapedClipOf(RenderObject parent) {
  if (parent is! RenderBox || !parent.hasSize) return null;
  final box = Offset.zero & parent.size;
  Path? rrect(RRect r) => r.isRect ? null : (Path()..addRRect(r));
  return switch (parent) {
    RenderClipRRect(clipBehavior: Clip.none) ||
    RenderClipRSuperellipse(clipBehavior: Clip.none) ||
    RenderClipOval(clipBehavior: Clip.none) ||
    RenderClipPath(clipBehavior: Clip.none) ||
    RenderPhysicalModel(clipBehavior: Clip.none) ||
    RenderPhysicalShape(clipBehavior: Clip.none) => null,
    RenderClipRRect(:final clipper?) => rrect(clipper.getClip(parent.size)),
    RenderClipRRect(:final borderRadius, :final textDirection) => rrect(
      borderRadius.resolve(textDirection).toRRect(box),
    ),
    RenderClipRSuperellipse(:final clipper?) =>
      Path()..addRSuperellipse(clipper.getClip(parent.size)),
    RenderClipRSuperellipse(:final borderRadius, :final textDirection) =>
      borderRadius.resolve(textDirection) == BorderRadius.zero
          ? null
          : (Path()..addRSuperellipse(
              borderRadius.resolve(textDirection).toRSuperellipse(box),
            )),
    RenderClipOval(:final clipper) =>
      Path()..addOval(clipper?.getClip(parent.size) ?? box),
    RenderClipPath(:final clipper?) => clipper.getClip(parent.size),
    RenderPhysicalModel(shape: BoxShape.circle) => Path()..addOval(box),
    RenderPhysicalModel(:final borderRadius?) => rrect(
      borderRadius.toRRect(box),
    ),
    RenderPhysicalShape(:final clipper?) => clipper.getClip(parent.size),
    _ => null,
  };
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
  Path? clipPath;
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
      final shaped = _shapedClipOf(
        parent,
      )?.transform(parent.getTransformTo(null).storage);
      if (shaped != null) {
        clipPath = clipPath == null
            ? shaped
            : Path.combine(PathOperation.intersect, clipPath, shaped);
      }
    }
    child = parent;
  }
  return PaintChain(
    painted: painted,
    opacity: opacity,
    clip: clip,
    clipPath: clipPath,
    order: order.reversed.toList(),
  );
}
