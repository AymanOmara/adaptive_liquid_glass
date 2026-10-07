import 'package:flutter/animation.dart' show Curve, Curves;

/// iOS 26's full-screen cover, estimated from SwiftUI's
/// `.fullScreenCover` (UIKit defaults); not measured.
abstract final class FullScreenCoverMetrics {
  /// The cover sliding up over the page (estimated).
  static const Duration duration = Duration(milliseconds: 500);

  /// The cover sliding back down and away (estimated).
  static const Duration reverseDuration = Duration(milliseconds: 400);

  /// The slide-up's curve (estimated).
  static const Curve curve = Curves.fastEaseInToSlowEaseOut;

  /// The slide-down's curve, an ease-in-out traced in reverse (estimated).
  static const Curve reverseCurve = Curves.easeInOutCubic;
}
