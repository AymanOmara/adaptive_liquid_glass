part of 'glass_shape.dart';

/// See [GlassShape.capsule].
final class CapsuleGlassShape extends GlassShape {
  /// Creates a capsule shape.
  const CapsuleGlassShape();

  @override
  double resolveRadius(Size size, {double? concentricRadius}) =>
      size.shortestSide / 2;

  @override
  bool operator ==(Object other) => other is CapsuleGlassShape;

  @override
  int get hashCode => (CapsuleGlassShape).hashCode;
}
