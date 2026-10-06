import 'package:flutter/painting.dart';

/// Text as iOS sets it: SF Pro's tracking depends on the point size, which
/// Flutter does not apply (and Material's text themes add their own
/// letter spacing on top).
abstract final class IOSText {
  /// Apple's tracking (points) by text size, from the Human Interface
  /// Guidelines' Dynamic Type table for SF Pro.
  static const Map<int, double> _tracking = {
    10: 0.12,
    11: 0.06,
    12: 0,
    13: -0.08,
    14: -0.15,
    15: -0.23,
    16: -0.31,
    17: -0.43,
    20: -0.45,
    22: -0.26,
    28: 0.38,
    34: 0.40,
  };

  /// The tracking for [size]: the nearest size in Apple's table.
  static double tracking(double size) {
    var best = 17;
    for (final s in _tracking.keys) {
      if ((s - size).abs() < (best - size).abs()) best = s;
    }
    return _tracking[best]!;
  }

  /// A style of [size] and [weight] with iOS's tracking.
  static TextStyle style(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: tracking(size),
    color: color,
  );
}
