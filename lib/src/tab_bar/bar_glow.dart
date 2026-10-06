import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The light a held tab lens casts on its bar: iOS brightens the bar
/// around the lens (Kept over black: about +25 grey within 50 pt, fading
/// with a Gaussian of [sigma]).
class BarGlow extends CustomPainter {
  /// A glow at [centre] of peak [opacity] (white).
  const BarGlow({required this.centre, required this.opacity, this.sigma = 57});

  /// The glow's centre, in the painted box.
  final Offset centre;

  /// Peak white opacity, at [centre].
  final double opacity;

  /// Gaussian falloff (logical px).
  final double sigma;

  static const int _stops = 8;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final radius = sigma * 3;
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= _stops; i++) {
      final s = i / _stops;
      final r = s * 3;
      colors.add(
        const Color(0xFFFFFFFF).withValues(
          alpha: opacity * math.exp(-r * r / 2) * (i == _stops ? 0 : 1),
        ),
      );
      stops.add(s);
    }
    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(BarGlow old) =>
      old.centre != centre || old.opacity != opacity || old.sigma != sigma;
}
