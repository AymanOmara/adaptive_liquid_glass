import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

part 'capsule_glass_shape.dart';
part 'circle_glass_shape.dart';
part 'concentric_glass_shape.dart';
part 'rect_glass_shape.dart';

/// The shape a piece of Liquid Glass is drawn in.
///
/// Mirrors the `in:` argument of SwiftUI's `glassEffect(_:in:)`. Corners use
/// Apple's continuous curve (a rounded superellipse), never circular arcs.
///
/// ```dart
/// const GlassShape.capsule()     // the default
/// const GlassShape.circle()
/// const GlassShape.rect(20)      // continuous corners of radius 20
/// const GlassShape.concentric()  // follows the enclosing glass's corners
/// ```
@immutable
sealed class GlassShape {
  const GlassShape();

  /// A capsule: corner radius is half the shortest side.
  const factory GlassShape.capsule() = CapsuleGlassShape;

  /// A circle fitted to the shortest side, centred in the box.
  const factory GlassShape.circle() = CircleGlassShape;

  /// A rectangle with continuous corners of [cornerRadius].
  const factory GlassShape.rect(double cornerRadius) = RectGlassShape;

  /// A rectangle whose corners are concentric with the enclosing glass.
  ///
  /// Outside any enclosing glass it behaves like [GlassShape.capsule].
  const factory GlassShape.concentric({double minimum}) = ConcentricGlassShape;

  /// The rect the shape occupies inside a box of [size].
  Rect resolveRect(Size size) => Offset.zero & size;

  /// The corner radius in logical pixels for a box of [size].
  ///
  /// [concentricRadius] is supplied by the group for [ConcentricGlassShape].
  double resolveRadius(Size size, {double? concentricRadius});

  /// The equivalent Flutter border, for clipping and Material rendering.
  OutlinedBorder toBorder(Size size) => RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(resolveRadius(size)),
  );
}

/// Radius for a child whose corners are concentric with [container].
///
/// The inset is the smallest distance between the child's and the
/// container's edges; the result is `containerRadius - inset`, floored at
/// [minimum].
double concentricRadius({
  required Rect container,
  required double containerRadius,
  required Rect child,
  double minimum = 0,
}) {
  final inset = [
    child.left - container.left,
    child.top - container.top,
    container.right - child.right,
    container.bottom - child.bottom,
  ].reduce(math.min);
  return math.max(containerRadius - math.max(inset, 0), minimum);
}
