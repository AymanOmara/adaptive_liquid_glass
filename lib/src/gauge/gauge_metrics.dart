import 'package:flutter/painting.dart' show FontWeight;

/// SwiftUI's `Gauge` on iOS 26, measured from the reference scene
/// (iOS 26.4, iPhone 17 Pro at 3x; `tool/reference/side_by_side.sh
/// gauge`) unless a value says estimated or fitted.
abstract final class GaugeMetrics {
  /// The linear track's height, a capsule (measured: 16).
  static const double linearTrackHeight = 16;

  /// The gap between the label and the track's row (fitted: the label's
  /// cap top 33 pt above the track).
  static const double linearLabelGap = 15;

  /// The gap between the track's row and the current value label below
  /// it (fitted: the value's cap top 15.67 pt below the track).
  static const double linearValueGap = 10;

  /// The gap between the linear track and the min/max labels beside it
  /// (measured: 8.67 to the "0" glyph).
  static const double minMaxGap = 8;

  /// The linear gauge's label, value and min/max text size (measured).
  static const double labelSize = 17;

  /// The circular gauges' diameter (measured: 58).
  static const double circularDiameter = 58;

  /// The circular gauges' stroke (measured: 5.67).
  static const double circularStroke = 5.67;

  /// The accessory ring's sweep in degrees; the rest is the bottom gap
  /// (measured: its ends 28.7° below the horizontal).
  static const double circularSweepDegrees = 237.4;

  /// The capacity ring's track: the tint at this opacity (measured: 166
  /// on white for black).
  static const double circularTrackOpacity = 0.35;

  /// The value dot's diameter on the accessory ring (measured: the
  /// stroke's width).
  static const double circularDotDiameter = 5.67;

  /// The clear gap around the accessory ring's value dot (measured: 2).
  static const double circularDotGap = 2;

  /// The current value label's size inside a ring (measured: 17.33 pt
  /// digits).
  static const double circularValueSize = 24;

  /// The current value label's weight inside a ring (estimated).
  static const FontWeight circularValueWeight = FontWeight.w500;

  /// How far the accessory ring's value sits above its centre (measured:
  /// the digits centre 1.17 pt high).
  static const double circularValueLift = 1.5;

  /// The min/max labels' size under the accessory ring's ends (measured:
  /// 8.33 pt digits).
  static const double circularEndLabelSize = 12;

  /// The gap between the accessory ring's min and max labels, which
  /// centre as a pair under the ring (fitted: 15.67 pt between glyphs).
  static const double circularEndLabelGap = 14.5;

  /// The min/max labels' box bottom above the ring's box bottom (fitted:
  /// the digits' baseline 52.67 pt below the ring's top).
  static const double circularEndLabelBottom = 2.5;

  /// The Material path's linear track corner radius (estimated).
  static const double materialTrackRadius = 2;
}
