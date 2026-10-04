import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';
import '../core/glass_shape.dart';
import '../core/shape_border.dart';

/// Glass without shader support: blur, tint and a rim; no lensing or merging.
class DegradedGlass extends StatelessWidget {
  /// Creates a degraded glass surface.
  const DegradedGlass({
    super.key,
    required this.glass,
    required this.shape,
    required this.constants,
    this.opaqueColor,
    required this.child,
  });

  /// Glass description.
  final Glass glass;

  /// Shape.
  final GlassShape shape;

  /// Rendering constants.
  final GlassConstants constants;

  /// Non-null when Reduce Transparency forces a solid surface.
  final Color? opaqueColor;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (glass.variant == GlassVariant.identity) return child;
    final border = sizeIndependentBorder(shape);
    final c = constants.of(
      glass.variant,
      MediaQuery.platformBrightnessOf(context),
    );
    final tint = glass.tintColor;

    final opaque = opaqueColor;
    if (opaque != null) {
      return DecoratedBox(
        decoration: ShapeDecoration(color: opaque, shape: border),
        child: child,
      );
    }

    final fill = tint != null
        ? tint.withValues(alpha: c.tintStrength * tint.a)
        : c.fillColor.withValues(alpha: c.fillOpacity);
    return ClipPath(
      clipper: ShapeBorderClipper(shape: border),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: c.blurSigma, sigmaY: c.blurSigma),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: fill,
            shape: border.copyWith(
              side: BorderSide(
                color: const Color(
                  0xFFFFFFFF,
                ).withValues(alpha: c.rimIntensity * 0.6),
                width: c.rimWidth,
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
