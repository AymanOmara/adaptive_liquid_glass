import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';
import '../core/glass_shape.dart';
import '../core/shape_border.dart';

/// The paint values of shader-less glass: blur, fill and rim.
@immutable
class DegradedLook {
  /// Resolves the look of [glass] in [brightness].
  factory DegradedLook.of(
    Glass glass,
    GlassConstants constants,
    Brightness brightness,
  ) {
    final c = constants.of(glass.variant, brightness);
    final tint = glass.tintColor;
    return DegradedLook._(
      blurSigma: c.blurSigma,
      fill: tint != null
          ? tint.withValues(alpha: c.tintStrength * tint.a)
          : c.fillColor.withValues(alpha: c.fillOpacity),
      rim: BorderSide(
        color: const Color(0xFFFFFFFF).withValues(alpha: c.rimIntensity * 0.6),
        width: c.rimWidth,
      ),
    );
  }

  const DegradedLook._({
    required this.blurSigma,
    required this.fill,
    required this.rim,
  });

  /// Backdrop blur sigma, logical px.
  final double blurSigma;

  /// Body fill.
  final Color fill;

  /// Edge highlight.
  final BorderSide rim;

  @override
  bool operator ==(Object other) =>
      other is DegradedLook &&
      other.blurSigma == blurSigma &&
      other.fill == fill &&
      other.rim == rim;

  @override
  int get hashCode => Object.hash(blurSigma, fill, rim);
}

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

    final opaque = opaqueColor;
    if (opaque != null) {
      return DecoratedBox(
        decoration: ShapeDecoration(color: opaque, shape: border),
        child: child,
      );
    }

    final look = DegradedLook.of(
      glass,
      constants,
      MediaQuery.platformBrightnessOf(context),
    );
    return ClipPath(
      clipper: ShapeBorderClipper(shape: border),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: look.blurSigma,
          sigmaY: look.blurSigma,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: look.fill,
            shape: border.copyWith(side: look.rim),
          ),
          child: child,
        ),
      ),
    );
  }
}
