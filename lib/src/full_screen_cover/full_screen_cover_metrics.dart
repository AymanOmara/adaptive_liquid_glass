import 'package:flutter/animation.dart' show Cubic, Curve, FlippedCurve;
import 'package:flutter/physics.dart' show SpringDescription;

import '../button/glass_button_metrics.dart';
import '../sheet/sheet_metrics.dart';

/// iOS 26's full-screen cover. The motion is fitted from a screen
/// recording of SwiftUI's `.fullScreenCover` (iOS 26.4, iPhone 17 Pro,
/// 60 fps; the cover's top edge per frame, `-controls covertiming`) and
/// re-checked against a second recording: RMS error 0.6% of the screen's
/// height sliding up, 0.5% sliding down (worst frame 2.1%). SwiftUI's
/// cover has no drag to dismiss (re-checked 2026-10-14: a downward drag
/// leaves it in place), so there is nothing to measure: drag is off by
/// default (`dragToDismiss`), and opting in borrows the sheet's thresholds
/// below by design. SwiftUI's cover has no close button of its own
/// either; ours is measured from a close-role toolbar button in it.
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

  /// The close button's inset from the screen's trailing edge
  /// (measured: SwiftUI's close-role toolbar button, `-controls
  /// coverclose`, "components" → "cover_close").
  static const double closeButtonInset = 16;

  /// The close button's gap below the safe area's top (measured: flush).
  static const double closeButtonTop = 0;

  /// The close button's diameter, a navigation-bar item's (measured).
  static const double closeButtonSize = 44;

  /// The close button: a 44-pt glass xmark circle.
  static const GlassButtonMetrics closeButton = GlassButtonMetrics(
    height: closeButtonSize,
    padding: 14,
    fontSize: 17,
    // CupertinoIcons glyphs are padded: 26 gives SF's 21-pt bar ink.
    iconSize: 26,
    iconGap: 6,
    iconOnlyHeight: closeButtonSize,
    iconOnlyExtraWidth: 0,
    cornerRadius: 12,
  );
}
