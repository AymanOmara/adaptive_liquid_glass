import 'package:flutter/foundation.dart';
import 'glass_json.dart';

/// Motion constants for `.interactive()` and `glassId` morphs.
@immutable
class GlassMotionConstants {
  /// Creates motion constants.
  const GlassMotionConstants({
    required this.pressGrowthArea,
    required this.pressScaleMax,
    required this.pressStretch,
    required this.glowRadius,
    required this.pressResponse,
    required this.pressDamping,
    required this.releaseResponse,
    required this.releaseDamping,
    required this.morphResponse,
    required this.morphDamping,
  });

  /// Reads keys present in [j]; missing keys come from [base].
  factory GlassMotionConstants.fromJson(
    Map<String, Object?> j,
    GlassMotionConstants base,
  ) => GlassMotionConstants(
    pressGrowthArea: GlassJson.number(
      j,
      'pressGrowthArea',
      base.pressGrowthArea,
    ),
    pressScaleMax: GlassJson.number(j, 'pressScaleMax', base.pressScaleMax),
    pressStretch: GlassJson.number(j, 'pressStretch', base.pressStretch),
    glowRadius: GlassJson.number(j, 'glowRadius', base.glowRadius),
    pressResponse: GlassJson.number(j, 'pressResponse', base.pressResponse),
    pressDamping: GlassJson.number(j, 'pressDamping', base.pressDamping),
    releaseResponse: GlassJson.number(
      j,
      'releaseResponse',
      base.releaseResponse,
    ),
    releaseDamping: GlassJson.number(j, 'releaseDamping', base.releaseDamping),
    morphResponse: GlassJson.number(j, 'morphResponse', base.morphResponse),
    morphDamping: GlassJson.number(j, 'morphDamping', base.morphDamping),
  );

  /// Area (pt²) a pressed shape gains at full press: its uniform scale is
  /// `sqrt(1 + pressGrowthArea / (w·h))`, capped at [pressScaleMax], so
  /// small shapes grow more than large ones.
  final double pressGrowthArea;

  /// Largest uniform press scale.
  final double pressScaleMax;

  /// Extra scale along the touch direction at full press.
  final double pressStretch;

  /// Radius of the touch glow.
  final double glowRadius;

  /// SwiftUI spring response for the press-in.
  final double pressResponse;

  /// SwiftUI damping fraction for the press-in.
  final double pressDamping;

  /// SwiftUI spring response for the release.
  final double releaseResponse;

  /// SwiftUI damping fraction for the release.
  final double releaseDamping;

  /// SwiftUI spring response for morphs.
  final double morphResponse;

  /// SwiftUI damping fraction for morphs.
  final double morphDamping;

  /// JSON form.
  Map<String, double> toJson() => {
    'pressGrowthArea': pressGrowthArea,
    'pressScaleMax': pressScaleMax,
    'pressStretch': pressStretch,
    'glowRadius': glowRadius,
    'pressResponse': pressResponse,
    'pressDamping': pressDamping,
    'releaseResponse': releaseResponse,
    'releaseDamping': releaseDamping,
    'morphResponse': morphResponse,
    'morphDamping': morphDamping,
  };

  @override
  bool operator ==(Object other) =>
      other is GlassMotionConstants && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}
