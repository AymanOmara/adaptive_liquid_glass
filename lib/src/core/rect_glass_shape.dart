part of 'glass_shape.dart';

/// See [GlassShape.rect].
final class RectGlassShape extends GlassShape {
  /// Creates a rectangle with continuous corners.
  const RectGlassShape(this.cornerRadius);

  /// Requested corner radius; clamped to half the shortest side.
  final double cornerRadius;

  @override
  double resolveRadius(Size size, {double? concentricRadius}) =>
      cornerRadius.clamp(0.0, size.shortestSide / 2);

  @override
  bool operator ==(Object other) =>
      other is RectGlassShape && other.cornerRadius == cornerRadius;

  @override
  int get hashCode => cornerRadius.hashCode;
}
