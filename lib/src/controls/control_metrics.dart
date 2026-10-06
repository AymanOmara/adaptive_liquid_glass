import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's toggle, slider and segmented control. Approximate: read from
/// iOS 26.4 screenshots, not yet fitted against SwiftUI scenes the way the
/// glass and tab bar are.
abstract final class ControlMetrics {
  /// The toggle's track.
  static const double toggleWidth = 63;

  /// See [toggleWidth].
  static const double toggleHeight = 28;

  /// The thumb's inset from the track's edge (toggle and segmented
  /// control).
  static const double thumbInset = 2;

  /// The toggle's thumb at rest, a capsule.
  static const double toggleThumbWidth = 37;

  /// The slider's track thickness.
  static const double sliderTrack = 6;

  /// The slider's thumb at rest, a capsule.
  static const double sliderThumbWidth = 38;

  /// See [sliderThumbWidth].
  static const double sliderThumbHeight = 24;

  /// The slider's height: its touch target.
  static const double sliderHeight = 44;

  /// The segmented control's height.
  static const double segmentedHeight = 36;

  /// The segmented control's label size.
  static const double segmentedFontSize = 14;

  /// How much a pressed thumb grows into its lens, across and down.
  static const double lensScaleX = 1.35;

  /// See [lensScaleX].
  static const double lensScaleY = 1.55;

  /// The thumb growing into a lens and shrinking back (the tab bar's
  /// press spring).
  static final SpringDescription press = swiftUISpring(
    response: 0.381,
    dampingFraction: 0.752,
  );

  /// The thumb moving to a new value.
  static final SpringDescription slide = swiftUISpring(
    response: 0.3,
    dampingFraction: 0.78,
  );
}
