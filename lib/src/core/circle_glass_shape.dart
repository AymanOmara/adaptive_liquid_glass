part of 'glass_shape.dart';

/// See [GlassShape.circle].
final class CircleGlassShape extends GlassShape {
  /// Creates a circle shape.
  const CircleGlassShape();

  @override
  Rect resolveRect(Size size) => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: size.shortestSide,
    height: size.shortestSide,
  );

  @override
  double resolveRadius(Size size, {double? concentricRadius}) =>
      size.shortestSide / 2;

  @override
  OutlinedBorder toBorder(Size size) => const CircleBorder();

  @override
  bool operator ==(Object other) => other is CircleGlassShape;

  @override
  int get hashCode => (CircleGlassShape).hashCode;
}
