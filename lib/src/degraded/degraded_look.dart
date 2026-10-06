import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_constants.dart';

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
        color: GlassColors.white.withValues(alpha: c.rimIntensity * 0.6),
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
