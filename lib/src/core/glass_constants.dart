import 'package:flutter/foundation.dart';

import 'glass.dart';

GlassVariantConstants _v(Map<String, Object?> j, String key,
        GlassVariantConstants base) =>
    GlassVariantConstants.fromJson(
        (j[key] as Map?)?.cast<String, Object?>() ?? const {}, base);

double _d(Map<String, Object?> j, String k, double fallback) =>
    (j[k] as num?)?.toDouble() ?? fallback;

/// Per-variant rendering constants (lengths in logical px).
@immutable
class GlassVariantConstants {
  /// Creates variant constants.
  const GlassVariantConstants({
    required this.blurSigma,
    required this.lensBand,
    required this.lensStrength,
    required this.dispersion,
    required this.rimWidth,
    required this.rimIntensity,
    required this.lumaLift,
    required this.dim,
    required this.shadowRadius,
    required this.shadowOpacity,
    required this.tintStrength,
  });

  /// Reads keys present in [j]; missing keys come from [base].
  factory GlassVariantConstants.fromJson(
          Map<String, Object?> j, GlassVariantConstants base) =>
      GlassVariantConstants(
        blurSigma: _d(j, 'blurSigma', base.blurSigma),
        lensBand: _d(j, 'lensBand', base.lensBand),
        lensStrength: _d(j, 'lensStrength', base.lensStrength),
        dispersion: _d(j, 'dispersion', base.dispersion),
        rimWidth: _d(j, 'rimWidth', base.rimWidth),
        rimIntensity: _d(j, 'rimIntensity', base.rimIntensity),
        lumaLift: _d(j, 'lumaLift', base.lumaLift),
        dim: _d(j, 'dim', base.dim),
        shadowRadius: _d(j, 'shadowRadius', base.shadowRadius),
        shadowOpacity: _d(j, 'shadowOpacity', base.shadowOpacity),
        tintStrength: _d(j, 'tintStrength', base.tintStrength),
      );

  /// Gaussian sigma of the frost blur.
  final double blurSigma;

  /// Width of the refracting edge band.
  final double lensBand;

  /// Lens displacement as a fraction of [lensBand]; sign sets direction.
  final double lensStrength;

  /// Red/blue split as a fraction of the lens displacement.
  final double dispersion;

  /// Width of the specular rim.
  final double rimWidth;

  /// Brightness added at the rim.
  final double rimIntensity;

  /// Lift applied to dark content behind the glass.
  final double lumaLift;

  /// Darkening applied to the content (used by `clear`).
  final double dim;

  /// Shadow falloff radius outside the shape.
  final double shadowRadius;

  /// Shadow strength at the shape edge.
  final double shadowOpacity;

  /// How strongly `.tint()` colours the glass.
  final double tintStrength;

  /// JSON form.
  Map<String, double> toJson() => {
        'blurSigma': blurSigma,
        'lensBand': lensBand,
        'lensStrength': lensStrength,
        'dispersion': dispersion,
        'rimWidth': rimWidth,
        'rimIntensity': rimIntensity,
        'lumaLift': lumaLift,
        'dim': dim,
        'shadowRadius': shadowRadius,
        'shadowOpacity': shadowOpacity,
        'tintStrength': tintStrength,
      };

  @override
  bool operator ==(Object other) =>
      other is GlassVariantConstants && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// Motion constants for `.interactive()` and `glassId` morphs.
@immutable
class GlassMotionConstants {
  /// Creates motion constants.
  const GlassMotionConstants({
    required this.pressScale,
    required this.pressStretch,
    required this.glowRadius,
    required this.pressResponse,
    required this.pressDamping,
    required this.morphResponse,
    required this.morphDamping,
  });

  /// Reads keys present in [j]; missing keys come from [base].
  factory GlassMotionConstants.fromJson(
          Map<String, Object?> j, GlassMotionConstants base) =>
      GlassMotionConstants(
        pressScale: _d(j, 'pressScale', base.pressScale),
        pressStretch: _d(j, 'pressStretch', base.pressStretch),
        glowRadius: _d(j, 'glowRadius', base.glowRadius),
        pressResponse: _d(j, 'pressResponse', base.pressResponse),
        pressDamping: _d(j, 'pressDamping', base.pressDamping),
        morphResponse: _d(j, 'morphResponse', base.morphResponse),
        morphDamping: _d(j, 'morphDamping', base.morphDamping),
      );

  /// Uniform scale gained at full press.
  final double pressScale;

  /// Extra scale along the touch direction at full press.
  final double pressStretch;

  /// Radius of the touch glow.
  final double glowRadius;

  /// SwiftUI spring response for press/release.
  final double pressResponse;

  /// SwiftUI damping fraction for press/release.
  final double pressDamping;

  /// SwiftUI spring response for morphs.
  final double morphResponse;

  /// SwiftUI damping fraction for morphs.
  final double morphDamping;

  /// JSON form.
  Map<String, double> toJson() => {
        'pressScale': pressScale,
        'pressStretch': pressStretch,
        'glowRadius': glowRadius,
        'pressResponse': pressResponse,
        'pressDamping': pressDamping,
        'morphResponse': morphResponse,
        'morphDamping': morphDamping,
      };

  @override
  bool operator ==(Object other) =>
      other is GlassMotionConstants && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

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
    required this.motion,
  });

  /// Reads keys present in [j]; missing keys come from [standard].
  factory GlassConstants.fromJson(Map<String, Object?> j) => GlassConstants(
        regular: _v(j, 'regular', standard.regular),
        clear: _v(j, 'clear', standard.clear),
        regularDark: _v(j, 'regularDark', standard.regularDark),
        clearDark: _v(j, 'clearDark', standard.clearDark),
        cornerExponent: _d(j, 'cornerExponent', standard.cornerExponent),
        motion: GlassMotionConstants.fromJson(
            (j['motion'] as Map?)?.cast<String, Object?>() ?? const {},
            standard.motion),
      );

  /// The shipped values. Fitted in Task 16 against `tool/scenes/scenes.json`.
  static const GlassConstants standard = GlassConstants(
    regular: GlassVariantConstants(
      blurSigma: 4,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.55,
      lumaLift: 0.08,
      dim: 0,
      shadowRadius: 12,
      shadowOpacity: 0.12,
      tintStrength: 0.35,
    ),
    clear: GlassVariantConstants(
      blurSigma: 1,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.6,
      lumaLift: 0,
      dim: 0.2,
      shadowRadius: 12,
      shadowOpacity: 0.10,
      tintStrength: 0.35,
    ),
    regularDark: GlassVariantConstants(
      blurSigma: 4,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.4,
      lumaLift: 0,
      dim: 0.15,
      shadowRadius: 12,
      shadowOpacity: 0.2,
      tintStrength: 0.35,
    ),
    clearDark: GlassVariantConstants(
      blurSigma: 1,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.45,
      lumaLift: 0,
      dim: 0.3,
      shadowRadius: 12,
      shadowOpacity: 0.18,
      tintStrength: 0.35,
    ),
    cornerExponent: 4,
    motion: GlassMotionConstants(
      pressScale: 0.1,
      pressStretch: 0.08,
      glowRadius: 60,
      pressResponse: 0.35,
      pressDamping: 0.65,
      morphResponse: 0.45,
      morphDamping: 0.75,
    ),
  );

  /// Regular-glass constants.
  final GlassVariantConstants regular;

  /// Clear-glass constants.
  final GlassVariantConstants clear;

  /// Regular glass in dark mode.
  final GlassVariantConstants regularDark;

  /// Clear glass in dark mode.
  final GlassVariantConstants clearDark;

  /// Superellipse exponent approximating Apple's continuous corners.
  final double cornerExponent;

  /// Motion constants.
  final GlassMotionConstants motion;

  /// Constants for [variant] in [brightness]; `identity` never draws, so it
  /// maps to regular.
  GlassVariantConstants of(GlassVariant variant,
      [Brightness brightness = Brightness.light]) {
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
      other.motion == motion;

  @override
  int get hashCode => Object.hash(
      regular, clear, regularDark, clearDark, cornerExponent, motion);
}
