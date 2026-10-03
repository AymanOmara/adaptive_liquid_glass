import 'dart:ui' show Brightness;

import 'package:flutter/painting.dart';

import 'glass_shape.dart';

/// A border that needs no layout size: used by Material and degraded paths.
OutlinedBorder sizeIndependentBorder(GlassShape shape) => switch (shape) {
  CapsuleGlassShape() || ConcentricGlassShape() => const StadiumBorder(),
  CircleGlassShape() => const CircleBorder(),
  RectGlassShape(:final cornerRadius) => RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(cornerRadius),
  ),
};

/// Solid fill used when Reduce Transparency is on (iOS system grouped
/// background colours).
Color opaqueGlassColor(Brightness brightness) => brightness == Brightness.dark
    ? const Color(0xFF1C1C1E)
    : const Color(0xFFF2F2F7);
