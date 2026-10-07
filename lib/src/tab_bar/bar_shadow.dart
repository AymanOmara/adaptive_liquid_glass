import 'package:flutter/widgets.dart';
import '../core/glass_colors.dart';
import 'tab_bar_metrics.dart';

/// The shadow under the bar's glass in shader mode: iOS's tab bar casts
/// a soft shadow below the bar (measured from SwiftUI `TabView`, iOS
/// 26.4, over white: offset 8 pt down, sigma 16.9 pt, about 7 % black),
/// where the shader's own shadow is centred on the glass.
class BarShadow extends CustomPainter {
  /// A shadow at [offset], blurred by [sigma], black at [opacity].
  const BarShadow({
    this.opacity = TabBarMetrics.shadowOpacity,
    this.offset = TabBarMetrics.shadowOffset,
    this.sigma = TabBarMetrics.shadowSigma,
  });

  /// The shadow's strength; 0 draws nothing.
  final double opacity;

  /// The shadow's shift from the glass, downwards.
  final Offset offset;

  /// Gaussian falloff (logical px).
  final double sigma;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final stadium = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.shortestSide / 2),
    );
    // The glass is translucent: the shadow is painted only outside it,
    // so the bar itself is not darkened.
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()
          ..addRect((Offset.zero & size).inflate(sigma * 3 + offset.distance)),
        Path()..addRRect(stadium),
      ),
    );
    canvas.drawRRect(
      stadium.shift(offset),
      Paint()
        ..color = GlassColors.tabBarShadow.withValues(alpha: opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BarShadow old) =>
      old.opacity != opacity || old.offset != offset || old.sigma != sigma;
}
