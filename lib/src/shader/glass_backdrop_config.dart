import 'package:flutter/widgets.dart';

import '../core/glass_constants.dart';

/// Per-group drawing parameters.
@immutable
class GlassBackdropConfig {
  /// Creates a config.
  const GlassBackdropConfig({
    required this.spacing,
    required this.lightAngle,
    required this.devicePixelRatio,
    required this.constants,
    required this.brightness,
    required this.highContrast,
    this.opaqueColor,
  });

  /// Light or dark appearance.
  final Brightness brightness;

  /// Group spacing (logical px).
  final double spacing;

  /// Light direction.
  final double lightAngle;

  /// Device pixel ratio.
  final double devicePixelRatio;

  /// Constants.
  final GlassConstants constants;

  /// Increase Contrast.
  final bool highContrast;

  /// Reduce Transparency fill.
  final Color? opaqueColor;

  @override
  bool operator ==(Object other) =>
      other is GlassBackdropConfig &&
      other.spacing == spacing &&
      other.lightAngle == lightAngle &&
      other.devicePixelRatio == devicePixelRatio &&
      other.constants == constants &&
      other.brightness == brightness &&
      other.highContrast == highContrast &&
      other.opaqueColor == opaqueColor;

  @override
  int get hashCode => Object.hash(
    spacing,
    lightAngle,
    devicePixelRatio,
    constants,
    brightness,
    highContrast,
    opaqueColor,
  );
}
