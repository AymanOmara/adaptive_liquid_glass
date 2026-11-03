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
    this.dragStretch = 0.08,
    this.dragStretchDistance = 60,
    this.pressGrowthLength = 0,
    this.pressSmallGrowth = 0,
    this.pressSmallLength = 0,
    this.smallReleaseResponse = 0,
    this.smallReleaseDamping = 0,
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
    pressGrowthLength: GlassJson.number(
      j,
      'pressGrowthLength',
      base.pressGrowthLength,
    ),
    pressSmallGrowth: GlassJson.number(
      j,
      'pressSmallGrowth',
      base.pressSmallGrowth,
    ),
    pressSmallLength: GlassJson.number(
      j,
      'pressSmallLength',
      base.pressSmallLength,
    ),
    smallReleaseResponse: GlassJson.number(
      j,
      'smallReleaseResponse',
      base.smallReleaseResponse,
    ),
    smallReleaseDamping: GlassJson.number(
      j,
      'smallReleaseDamping',
      base.smallReleaseDamping,
    ),
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
    dragStretch: GlassJson.number(j, 'dragStretch', base.dragStretch),
    dragStretchDistance: GlassJson.number(
      j,
      'dragStretchDistance',
      base.dragStretchDistance,
    ),
  );

  /// Area (pt²) a pressed shape gains at full press: its uniform scale is
  /// `sqrt(1 + pressGrowthArea / (w·h))`, capped at [pressScaleMax], so
  /// small shapes grow more than large ones.
  final double pressGrowthArea;

  /// When positive, replaces [pressGrowthArea]: a pressed shape's long side
  /// grows by `pressGrowthLength / sqrt(short side)` points (uniform scale
  /// `1 + pressGrowthLength / (long · sqrt(short))`), capped at
  /// [pressScaleMax]. Fits SwiftUI's capsules better than a fixed area.
  final double pressGrowthLength;

  /// Points a pressed small shape's long side grows by (uniform scale
  /// `1 + pressSmallGrowth / long`, capped at [pressScaleMax]) when that
  /// side is under [pressSmallLength]: SwiftUI presses small controls in a
  /// regime of their own, a fixed growth and a frost. 0 turns it off.
  final double pressSmallGrowth;

  /// Long side (pt) below which [pressSmallGrowth] applies.
  final double pressSmallLength;

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

  /// When positive, the release response of a shape whose long side is
  /// under [pressSmallLength]: SwiftUI releases small controls with a
  /// springier spring than large ones.
  final double smallReleaseResponse;

  /// When positive, the release damping fraction of a shape whose long side
  /// is under [pressSmallLength].
  final double smallReleaseDamping;

  /// SwiftUI spring response for morphs.
  final double morphResponse;

  /// SwiftUI damping fraction for morphs.
  final double morphDamping;

  /// Largest extra scale along an axis when the finger is dragged past the
  /// pressed shape's edge on that axis: the shape rubber-bands toward the
  /// finger, its opposite edge anchored. Estimated by eye from iOS 26
  /// buttons, not measured.
  final double dragStretch;

  /// Drag distance (pt) past the edge at which the stretch reaches
  /// `1 − 1/e` (63 %) of [dragStretch]; further drags add less and less.
  /// Estimated, not measured.
  final double dragStretchDistance;

  /// JSON form.
  Map<String, double> toJson() => {
    'pressGrowthArea': pressGrowthArea,
    'pressScaleMax': pressScaleMax,
    'pressGrowthLength': pressGrowthLength,
    'pressSmallGrowth': pressSmallGrowth,
    'pressSmallLength': pressSmallLength,
    'smallReleaseResponse': smallReleaseResponse,
    'smallReleaseDamping': smallReleaseDamping,
    'pressStretch': pressStretch,
    'glowRadius': glowRadius,
    'pressResponse': pressResponse,
    'pressDamping': pressDamping,
    'releaseResponse': releaseResponse,
    'releaseDamping': releaseDamping,
    'morphResponse': morphResponse,
    'morphDamping': morphDamping,
    'dragStretch': dragStretch,
    'dragStretchDistance': dragStretchDistance,
  };

  @override
  bool operator ==(Object other) =>
      other is GlassMotionConstants && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}
