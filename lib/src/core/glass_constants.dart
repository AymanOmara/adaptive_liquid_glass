import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'glass_json.dart';
import 'glass_motion_constants.dart';
import 'glass_variant.dart';
import 'glass_variant_constants.dart';

part 'glass_constants_standard.dart';

/// All fitted constants. Exported from `testing.dart` only.
@immutable
class GlassConstants {
  /// Creates a constants set.
  const GlassConstants({
    required this.regular,
    required this.clear,
    required this.regularDark,
    required this.clearDark,
    required this.cornerExponent,
    this.cornerZone = 1.0,
    this.mergeFactor = 1.0,
    required this.motion,
  });

  /// Reads keys present in [j]; missing keys come from [standard].
  factory GlassConstants.fromJson(Map<String, Object?> j) => GlassConstants(
    regular: GlassJson.variant(j, 'regular', standard.regular),
    clear: GlassJson.variant(j, 'clear', standard.clear),
    regularDark: GlassJson.variant(j, 'regularDark', standard.regularDark),
    clearDark: GlassJson.variant(j, 'clearDark', standard.clearDark),
    cornerExponent: GlassJson.number(
      j,
      'cornerExponent',
      standard.cornerExponent,
    ),
    cornerZone: GlassJson.number(j, 'cornerZone', standard.cornerZone),
    mergeFactor: GlassJson.number(j, 'mergeFactor', standard.mergeFactor),
    motion: GlassMotionConstants.fromJson(
      (j['motion'] as Map?)?.cast<String, Object?>() ?? const {},
      standard.motion,
    ),
  );

  /// The shipped values (certified at the Task A1 tree): the Task
  /// 17c constants (edge lens from Task 15c, size-dependent frost/fill from
  /// 17b, frost wide tail from 17c) plus the 17d additions (tone LUT, small
  /// dark-shape tone lift, clear lens grid, anisotropic frost), the A1
  /// continuous-corner outline and the g13 colour refit (fitted
  /// regular/regularDark tone LUTs, fill/saturation/tint), fitted by
  /// the NumPy model (`tool/fidelity/fit.py`) against SwiftUI screenshots
  /// of `tool/scenes/scenes.json`. Device-certified on the reference
  /// simulator: 55/75 scenes pass, median SSIM 0.9830 / median ΔE 1.29,
  /// min SSIM 0.9525, 0 scenes below 0.95 (75 in-set scenes). The g13
  /// refit adds a small-shape tone curve: shapes whose half shorter side
  /// is at or below 32 pt get the small tone LUT at full weight, fading
  /// linearly to off at 34 pt (SwiftUI's small glass has a steeper tone
  /// response, Task g13). Per-set and per-scene numbers, and
  /// the known residuals, live in
  /// `docs/superpowers/notes/fidelity-status.md` — cite that note, not
  /// per-set numbers here.
  static const GlassConstants standard = _standard;

  /// Regular-glass constants.
  final GlassVariantConstants regular;

  /// Clear-glass constants.
  final GlassVariantConstants clear;

  /// Regular glass in dark mode.
  final GlassVariantConstants regularDark;

  /// Clear glass in dark mode.
  final GlassVariantConstants clearDark;

  /// Superellipse exponent approximating Apple's continuous corners.
  ///
  /// Used for rectangles only; capsules and circles use exact circular arcs
  /// (exponent 2), like SwiftUI's `Capsule()` and `Circle()`.
  final double cornerExponent;

  /// Continuous-corner zone, as a multiple of the corner radius.
  ///
  /// Above 1 a rectangle's corner curve starts `cornerZone × radius` from
  /// the corner (capped at half the shorter side) and is a superellipse
  /// whose exponent is derived so it passes through the circular arc's 45°
  /// point, like Apple's continuous corners; it becomes a circular arc when
  /// the zone clamps to the radius (pills). 1 keeps [cornerExponent] with
  /// the curve starting at the radius. Applies to the outline only; capsules
  /// and circles stay exact circles. Fitted, not measured: see
  /// `docs/superpowers/notes/fidelity-status.md` (Task A1).
  final double cornerZone;

  /// Returns a copy with the given fields replaced.
  GlassConstants copyWith({
    GlassVariantConstants? regular,
    GlassVariantConstants? clear,
    GlassVariantConstants? regularDark,
    GlassVariantConstants? clearDark,
    double? cornerExponent,
    double? cornerZone,
    double? mergeFactor,
    GlassMotionConstants? motion,
  }) => GlassConstants(
    regular: regular ?? this.regular,
    clear: clear ?? this.clear,
    regularDark: regularDark ?? this.regularDark,
    clearDark: clearDark ?? this.clearDark,
    cornerExponent: cornerExponent ?? this.cornerExponent,
    cornerZone: cornerZone ?? this.cornerZone,
    mergeFactor: mergeFactor ?? this.mergeFactor,
    motion: motion ?? this.motion,
  );

  /// Smooth-union radius as a multiple of the group's spacing.
  final double mergeFactor;

  /// Motion constants.
  final GlassMotionConstants motion;

  /// Constants for [variant] in [brightness]; `identity` never draws, so it
  /// maps to regular.
  GlassVariantConstants of(
    GlassVariant variant, [
    Brightness brightness = Brightness.light,
  ]) {
    final dark = brightness == Brightness.dark;
    if (variant == GlassVariant.clear) return dark ? clearDark : clear;
    return dark ? regularDark : regular;
  }

  /// JSON form.
  Map<String, Object?> toJson() => {
    'regular': regular.toJson(),
    'clear': clear.toJson(),
    'regularDark': regularDark.toJson(),
    'clearDark': clearDark.toJson(),
    'cornerExponent': cornerExponent,
    'cornerZone': cornerZone,
    'mergeFactor': mergeFactor,
    'motion': motion.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is GlassConstants &&
      other.regular == regular &&
      other.clear == clear &&
      other.regularDark == regularDark &&
      other.clearDark == clearDark &&
      other.cornerExponent == cornerExponent &&
      other.cornerZone == cornerZone &&
      other.mergeFactor == mergeFactor &&
      other.motion == motion;

  @override
  int get hashCode => Object.hash(
    regular,
    clear,
    regularDark,
    clearDark,
    cornerExponent,
    cornerZone,
    mergeFactor,
    motion,
  );
}
