import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// Converts SwiftUI's `.spring(response:dampingFraction:)` to Flutter.
///
/// SwiftUI: stiffness = (2π / response)², damping = 4π·ζ / response, mass 1.
SpringDescription swiftUISpring({
  required double response,
  required double dampingFraction,
}) =>
    SpringDescription(
      mass: 1,
      stiffness: math.pow(2 * math.pi / response, 2).toDouble(),
      damping: 4 * math.pi * dampingFraction / response,
    );
