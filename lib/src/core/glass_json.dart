import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'glass_variant_constants.dart';

/// Reading and writing the fitted constants' JSON.
abstract final class GlassJson {
  /// Reads the variant set at [key], filling gaps from [base].
  static GlassVariantConstants variant(
    Map<String, Object?> j,
    String key,
    GlassVariantConstants base,
  ) => GlassVariantConstants.fromJson(
    (j[key] as Map?)?.cast<String, Object?>() ?? const {},
    base,
  );

  /// Reads a number, or [fallback] when absent.
  static double number(Map<String, Object?> j, String k, double fallback) =>
      (j[k] as num?)?.toDouble() ?? fallback;

  /// Reads a 9-entry knot list; a malformed one falls back to [fallback].
  static List<double> knots(
    Map<String, Object?> j,
    String k,
    List<double> fallback,
  ) {
    final v = j[k];
    if (v is List && v.length == 9 && v.every((e) => e is num)) {
      return List.unmodifiable([for (final e in v) (e as num).toDouble()]);
    }
    return fallback;
  }

  /// Map equality for JSON. [mapEquals] compares list values by identity, which breaks `==` across
  /// JSON round-trips now that [GlassVariantConstants] carries [List<double>]
  /// knots; compare top-level lists by contents.
  static bool equals(Map<String, Object?> a, Map<String, Object?> b) =>
      a.length == b.length &&
      a.entries.every(
        (e) =>
            identical(e.value, b[e.key]) ||
            (e.value is List && b[e.key] is List
                ? listEquals(e.value as List, b[e.key] as List)
                : e.value == b[e.key]),
      );

  /// Reads `"#RRGGBB"` or an int ARGB value. The result is always opaque (any
  /// alpha is dropped), so `toJson`'s `"#RRGGBB"` round-trips losslessly.
  static Color color(Map<String, Object?> j, String k, Color fallback) {
    final v = j[k];
    if (v == null) return fallback;
    Color opaque(int argb) => Color(0xFF000000 | (argb & 0xFFFFFF));
    if (v is int) return opaque(v);
    if (v is String) {
      final hex = v.startsWith('#') ? v.substring(1) : v;
      if (hex.length == 6 || hex.length == 8) {
        return opaque(int.parse(hex, radix: 16));
      }
    }
    throw FormatException('$k: expected "#RRGGBB" or an int ARGB, got $v');
  }

  /// Writes [c] as `"#RRGGBB"`.
  static String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
