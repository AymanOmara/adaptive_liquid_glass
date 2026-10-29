import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

import 'full_screen_cover_metrics.dart';

/// The optional, app-defined full-screen-cover drag gesture.
///
/// SwiftUI does not provide this gesture. Defaults preserve the package's
/// existing behavior and are independent of sheet configuration.
@immutable
class GlassFullScreenCoverDragConfiguration {
  /// Configures release thresholds, upward resistance and return motion.
  const GlassFullScreenCoverDragConfiguration({
    this.dismissFraction = FullScreenCoverMetrics.dismissFraction,
    this.flingVelocity = FullScreenCoverMetrics.flingVelocity,
    this.upwardResistance = FullScreenCoverMetrics.upwardResistance,
    this.settleSpring,
  }) : assert(dismissFraction > 0 && dismissFraction <= 1),
       assert(flingVelocity > 0),
       assert(upwardResistance >= 0 && upwardResistance <= 1);

  /// Fraction of the cover height required for a slow downward dismissal.
  final double dismissFraction;

  /// Downward release speed in logical pixels/second required for a fling.
  /// Use [double.infinity] to require the distance threshold instead.
  final double flingVelocity;

  /// Fraction of upward finger movement applied to the cover, from 0 to 1.
  final double upwardResistance;

  /// Return spring after a short, cancelled or refused drag.
  /// Null uses the cover's own default spring.
  final SpringDescription? settleSpring;
}
