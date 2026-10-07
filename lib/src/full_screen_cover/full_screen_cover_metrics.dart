import 'package:flutter/animation.dart' show Cubic, Curve, FlippedCurve;
import 'package:flutter/physics.dart' show SpringDescription;

import '../sheet/sheet_metrics.dart';

/// iOS 26's full-screen cover. The motion is fitted from a screen
/// recording of SwiftUI's `.fullScreenCover` (iOS 26.4, iPhone 17 Pro,
/// 60 fps; the cover's top edge per frame, `-controls covertiming`) and
/// re-checked against a second recording: RMS error 0.6% of the screen's
/// height sliding up, 0.5% sliding down (worst frame 2.1%). SwiftUI's cover has no drag to
/// dismiss or close button of its own: those follow the sheet and iOS 26's
/// close button, and say so.
abstract final class FullScreenCoverMetrics {
  /// The cover sliding up over the page (fitted: settled within a pixel
  /// after about 0.45 s).
  static const Duration duration = Duration(milliseconds: 440);

  /// The cover sliding back down and away (fitted).
  static const Duration reverseDuration = Duration(milliseconds: 406);

  /// The slide-up's curve: a fast start easing out (fitted).
  static const Curve curve = Cubic(0.27, 0.72, 0.24, 1);

  /// The slide-down's curve as the route reverses: the cover leaves fast
  /// and eases out below the screen (fitted, traced in reverse).
  static const Curve reverseCurve = FlippedCurve(Cubic(0.28, 0.52, 0.19, 1));

  /// How far down a released cover is dismissed, as a fraction of its
  /// height (the sheet's, [SheetMetrics.dismissFraction]).
  static const double dismissFraction = SheetMetrics.dismissFraction;

  /// The downward fling speed, in logical pixels per second, that
  /// dismisses the cover (the sheet's, [SheetMetrics.flingVelocity]).
  static const double flingVelocity = SheetMetrics.flingVelocity;

  /// How much an upward drag moves the cover, per point dragged.
  static const double upwardResistance = 0.3;

  /// A released cover springing back into place (the sheet's).
  static final SpringDescription spring = SheetMetrics.spring;

  /// The close button's inset from the safe area's top-trailing corner
  /// (estimated, as a toolbar item's 16 pt margin).
  static const double closeButtonInset = 16;
}
