import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'glass.dart';

GlassVariantConstants _v(
  Map<String, Object?> j,
  String key,
  GlassVariantConstants base,
) => GlassVariantConstants.fromJson(
  (j[key] as Map?)?.cast<String, Object?>() ?? const {},
  base,
);

double _d(Map<String, Object?> j, String k, double fallback) =>
    (j[k] as num?)?.toDouble() ?? fallback;

/// Reads `"#RRGGBB"` (opaque) or an int ARGB value.
Color _color(Map<String, Object?> j, String k, Color fallback) {
  final v = j[k];
  if (v == null) return fallback;
  if (v is int) return Color(v);
  if (v is String) {
    final hex = v.startsWith('#') ? v.substring(1) : v;
    if (hex.length == 6) return Color(0xFF000000 | int.parse(hex, radix: 16));
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
  }
  throw FormatException('$k: expected "#RRGGBB" or an int ARGB, got $v');
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

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
    required this.fillColor,
    required this.fillOpacity,
    required this.saturation,
    required this.dim,
    required this.shadowRadius,
    required this.shadowOpacity,
    required this.tintStrength,
  });

  /// Reads keys present in [j]; missing keys come from [base].
  factory GlassVariantConstants.fromJson(
    Map<String, Object?> j,
    GlassVariantConstants base,
  ) => GlassVariantConstants(
    blurSigma: _d(j, 'blurSigma', base.blurSigma),
    lensBand: _d(j, 'lensBand', base.lensBand),
    lensStrength: _d(j, 'lensStrength', base.lensStrength),
    dispersion: _d(j, 'dispersion', base.dispersion),
    rimWidth: _d(j, 'rimWidth', base.rimWidth),
    rimIntensity: _d(j, 'rimIntensity', base.rimIntensity),
    fillColor: _color(j, 'fillColor', base.fillColor),
    fillOpacity: _d(j, 'fillOpacity', base.fillOpacity),
    saturation: _d(j, 'saturation', base.saturation),
    dim: _d(j, 'dim', base.dim),
    shadowRadius: _d(j, 'shadowRadius', base.shadowRadius),
    shadowOpacity: _d(j, 'shadowOpacity', base.shadowOpacity),
    tintStrength: _d(j, 'tintStrength', base.tintStrength),
  );

  /// Gaussian sigma of the frost blur (logical px).
  ///
  /// Applied as `ImageFilter.blur` composed before the glass shader. The
  /// engine's effective sigma is somewhat smaller than requested (measured
  /// 0.84–0.92× on Impeller/iOS for 2–20 px; see
  /// `docs/superpowers/notes/shader-probe.md`); fitting absorbs this.
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

  /// Colour the content behind the glass is washed toward (opaque; JSON
  /// `"#RRGGBB"` or an int ARGB).
  final Color fillColor;

  /// How far the content is mixed toward [fillColor] (0 = untouched).
  final double fillOpacity;

  /// Saturation of the content behind the glass (1 = unchanged, 0 = grey).
  final double saturation;

  /// Darkening applied after the fill (used by `clear`).
  final double dim;

  /// Shadow falloff radius outside the shape.
  final double shadowRadius;

  /// Shadow strength at the shape edge.
  final double shadowOpacity;

  /// How strongly `.tint()` colours the glass.
  final double tintStrength;

  /// JSON form; [fillColor] is written as `"#RRGGBB"`.
  Map<String, Object> toJson() => {
    'blurSigma': blurSigma,
    'lensBand': lensBand,
    'lensStrength': lensStrength,
    'dispersion': dispersion,
    'rimWidth': rimWidth,
    'rimIntensity': rimIntensity,
    'fillColor': _hex(fillColor),
    'fillOpacity': fillOpacity,
    'saturation': saturation,
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
    Map<String, Object?> j,
    GlassMotionConstants base,
  ) => GlassMotionConstants(
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
    this.mergeFactor = 1.0,
    required this.motion,
  });

  /// Reads keys present in [j]; missing keys come from [standard].
  factory GlassConstants.fromJson(Map<String, Object?> j) => GlassConstants(
    regular: _v(j, 'regular', standard.regular),
    clear: _v(j, 'clear', standard.clear),
    regularDark: _v(j, 'regularDark', standard.regularDark),
    clearDark: _v(j, 'clearDark', standard.clearDark),
    cornerExponent: _d(j, 'cornerExponent', standard.cornerExponent),
    mergeFactor: _d(j, 'mergeFactor', standard.mergeFactor),
    motion: GlassMotionConstants.fromJson(
      (j['motion'] as Map?)?.cast<String, Object?>() ?? const {},
      standard.motion,
    ),
  );

  /// The shipped values. Fitted in Task 16 against `tool/scenes/scenes.json`.
  static const GlassConstants standard = GlassConstants(
    regular: GlassVariantConstants(
      blurSigma: 12,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.55,
      fillColor: Color(0xFFFFFFFF),
      fillOpacity: 0.30,
      saturation: 0.75,
      dim: 0,
      shadowRadius: 12,
      shadowOpacity: 0.12,
      tintStrength: 0.35,
    ),
    clear: GlassVariantConstants(
      blurSigma: 2,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.6,
      fillColor: Color(0xFFFFFFFF),
      fillOpacity: 0.05,
      saturation: 1.0,
      dim: 0.2,
      shadowRadius: 12,
      shadowOpacity: 0.10,
      tintStrength: 0.35,
    ),
    regularDark: GlassVariantConstants(
      blurSigma: 12,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.4,
      fillColor: Color(0xFF1C1C1E),
      fillOpacity: 0.55,
      saturation: 0.75,
      dim: 0,
      shadowRadius: 12,
      shadowOpacity: 0.2,
      tintStrength: 0.35,
    ),
    clearDark: GlassVariantConstants(
      blurSigma: 2,
      lensBand: 14,
      lensStrength: 0.35,
      dispersion: 0.15,
      rimWidth: 1.2,
      rimIntensity: 0.45,
      fillColor: Color(0xFF000000),
      fillOpacity: 0.20,
      saturation: 1.0,
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
  ///
  /// Used for rectangles only; capsules and circles use exact circular arcs
  /// (exponent 2), like SwiftUI's `Capsule()` and `Circle()`.
  final double cornerExponent;

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
      other.mergeFactor == mergeFactor &&
      other.motion == motion;

  @override
  int get hashCode => Object.hash(
    regular,
    clear,
    regularDark,
    clearDark,
    cornerExponent,
    mergeFactor,
    motion,
  );
}
