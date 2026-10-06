part of 'glass_shape.dart';

/// See [GlassShape.concentric].
final class ConcentricGlassShape extends GlassShape {
  /// Creates a concentric shape.
  const ConcentricGlassShape({this.minimum = 0});

  /// Smallest radius the shape will use.
  final double minimum;

  @override
  double resolveRadius(Size size, {double? concentricRadius}) =>
      (concentricRadius ?? size.shortestSide / 2).clamp(
        0.0,
        size.shortestSide / 2,
      );

  @override
  bool operator ==(Object other) =>
      other is ConcentricGlassShape && other.minimum == minimum;

  @override
  int get hashCode => minimum.hashCode;
}
