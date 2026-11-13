import 'dart:math' as math;
import 'package:flutter/painting.dart';

import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's context menu, measured from UIKit's UIContextMenuInteraction
/// (what SwiftUI's `.contextMenu` rides on) on iPhone 17 Pro / iOS 26.4,
/// opened programmatically in the reference harness (`-controls
/// contextmenuuikit`, `…left`, `…wide`; "components" → "context_menu" in
/// tool/reference/controls.json) and by idb's long press for the press
/// before the lift. SwiftUI's own, opened by idb's long press
/// (`-controls contextmenu`), presses, lifts, dims and closes as the
/// Flutter twin within a frame.
/// The menu itself is the measured glass menu
/// (`MenuMetrics`). The page behind is dimmed (`GlassColors
/// .contextMenuBarrier`) but not blurred: over 100-pt black and white
/// stripes its edges stay one pixel sharp (`-controls
/// contextmenuuikitstripes`).
abstract final class ContextMenuMetrics {
  // Motion, fitted from 60 fps frame dumps of UIKit's menu opening and
  // closing (`-controls contextmenuuikitmotion`, a tap opens it and a
  // second closes it; tool/fidelity/record_component_motion.sh).

  // The press before the lift, fitted from 60 fps frame dumps of idb long
  // presses of 0.3, 0.6 and 1.5 s on a 200 x 120 card (`-controls
  // contextmenuuikitmotion`), timed from the card's touchesBegan.

  /// The press: how long after touch-down the item starts to grow
  /// (fitted: 0.24 s).
  static const Duration pressDelay = Duration(milliseconds: 240);

  /// The press: the item easing up under the finger toward [pressGrow]
  /// (fitted, rms 0.2 pt; no overshoot). The lift interrupts it at about
  /// 1.06.
  static final SpringDescription pressSpring = swiftUISpring(
    response: 1,
    dampingFraction: 1,
  );

  /// The press: the scale [pressSpring] heads for (fitted: 1.074).
  static const double pressGrow = 1.074;

  /// How long the finger must stay down for the menu to open: a release
  /// after it still opens the menu (measured: a 0.3-s press settles back,
  /// a 0.6-s one opens; UIKit cancels the item's touches at 0.415 s).
  static const Duration pressRecognize = Duration(milliseconds: 415);

  /// When, after touch-down, the menu opens and the item lifts on from
  /// its pressed size (measured: 0.75–0.85 s, mean 0.8).
  static const Duration pressLift = Duration(milliseconds: 800);

  /// A press released early: the item settling back to rest, carrying on
  /// with the speed it was growing at (fitted to presses released at 0.3
  /// s, timed from touchesEnded, rms 0.3 pt: it rises for 0.07 s more).
  static final SpringDescription pressReleaseSpring = swiftUISpring(
    response: 0.445,
    dampingFraction: 1,
  );

  static double _pressT(double t) => t - pressDelay.inMicroseconds / 1e6;

  /// The item's scale [t] seconds after touch-down, while the finger is
  /// down and before the lift.
  static double pressed(double t) {
    final s = _pressT(t);
    if (s <= 0) return 1;
    return 1 + (pressGrow - 1) * SpringSimulation(pressSpring, 0, 1, 0).x(s);
  }

  /// How fast [pressed] grows [t] seconds after touch-down, per second.
  static double pressedVelocity(double t) {
    final s = _pressT(t);
    if (s <= 0) return 0;
    return (pressGrow - 1) * SpringSimulation(pressSpring, 0, 1, 0).dx(s);
  }

  /// Opening: the page's dim (fitted, rms 2.3%).
  static final SpringDescription dimSpring = swiftUISpring(
    response: 0.255,
    dampingFraction: 0.85,
  );

  /// Opening: how long the lift and the menu trail the dim (fitted: 1.3
  /// frames).
  static const Duration openLead = Duration(milliseconds: 22);

  /// Opening: the item lifting to its grown size (fitted, rms 1.7%; no
  /// overshoot).
  static final SpringDescription liftSpring = swiftUISpring(
    response: 0.16,
    dampingFraction: 1,
  );

  /// Opening: the menu growing from nothing at its edge by the item
  /// (fitted, rms 1.6%; it overshoots 2%).
  static final SpringDescription menuSpring = swiftUISpring(
    response: 0.225,
    dampingFraction: 0.82,
  );

  /// Closing: the item settling back (fitted, rms 0.9%).
  static final SpringDescription closeLiftSpring = swiftUISpring(
    response: 0.295,
    dampingFraction: 0.79,
  );

  /// Closing: the dim lifting (fitted, rms 1.3%).
  static final SpringDescription closeDimSpring = swiftUISpring(
    response: 0.37,
    dampingFraction: 0.79,
  );

  /// Closing: the menu fading and shrinking away (measured: gone within
  /// three frames).
  static const Duration closeMenuFade = Duration(milliseconds: 50);

  /// The route's opening, long enough for [menuSpring] to settle.
  static const Duration openDuration = Duration(milliseconds: 500);

  /// The route's closing, long enough for [closeDimSpring] to settle.
  static const Duration closeDuration = Duration(milliseconds: 450);

  /// The menu's width (measured: 250 by every card, two narrower than a
  /// `Menu`'s, its rows' columns 1 nearer its edge).
  static const double menuWidth = 250;

  /// The lifted item's shadow: black at 29% under its bounds, blurred by
  /// [previewShadowSigma], not offset, coming in with the dim (measured on
  /// the dimmed grey page: 14% darker at the item's edge on all four
  /// sides, gone 40 from it).
  static const Color previewShadowColor = Color(0x4A000000);

  /// The lifted item's shadow's blur, a Gaussian's sigma in points
  /// (fitted to the fall-off 1 to 40 from the item's edge).
  static const double previewShadowSigma = 20.5;

  /// [previewShadowColor] at [opacity] blurred by [previewShadowSigma],
  /// for an item drawn at [scale] (the blur is undone by it, so it
  /// measures in screen points).
  static BoxShadow previewShadow({double opacity = 1, double scale = 1}) {
    final sigma = previewShadowSigma / math.max(scale, 1e-3);
    return BoxShadow(
      color: previewShadowColor.withValues(
        alpha: previewShadowColor.a * opacity.clamp(0.0, 1.0),
      ),
      // BoxShadow's sigma is 0.57735 x blurRadius + 0.5.
      blurRadius: math.max(0, (sigma - 0.5) / 0.57735),
    );
  }

  /// The gap between the lifted item and the menu (measured: 16 under a
  /// 200 x 120 and a 360 x 80 card).
  static const double gap = 16;

  /// How much the lifted item grows (measured: a 200 x 120 card lifts to
  /// 226 x 135.7), unless that would bring it closer than [margin] to the
  /// screen's sides (a 360-pt card lifts to 369, 1.024).
  static const double lift = 1.13;

  /// The closest the lifted item and the menu come to the screen's sides
  /// (measured: both clamp to 16 near the leading edge).
  static const double margin = 16;

  /// The closest the lifted item comes to the safe area's top and bottom
  /// (measured: a card lifted past the home indicator stops 20 above the
  /// safe bottom; a tall card lifts to 20 below the safe top).
  static const double safeMargin = 20;

  /// Vertical room reserved for the menu beside an oversized preview.
  ///
  /// Fitted to the 600-pt reference card (iOS 26.4), where UIKit lifts
  /// the preview less and overlaps the menu with its end: about 593 pt
  /// of it stays visible above the menu on a 738-pt safe span. The value
  /// is chosen to match that capture, not measured directly.
  static const double tallPreviewMenuRoom = 112;

  /// Where an item at [rect] sits lifted on a screen of [size] with the
  /// safe area [padding]: grown by [lift] about its centre, less when it
  /// would exceed the horizontal margins or the space reserved for an
  /// oversized preview and its menu. The result stays [safeMargin]
  /// inside the vertical safe area.
  static Rect lifted(
    Rect rect,
    Size size, [
    EdgeInsets padding = EdgeInsets.zero,
  ]) {
    final room = math.max(0.0, size.width - 2 * margin);
    final minTop = padding.top + safeMargin;
    final safeBottom = size.height - padding.bottom - safeMargin;
    final verticalRoom = math.max(0.0, safeBottom - minTop);
    // UIKit lifts a card wider than the margins without growing it, but
    // never shrinks it to fit them (nothing measured shows it shrinking).
    final widthScale = rect.width > 0
        ? math.max(1.0, math.min(lift, room / rect.width))
        : lift;
    final oversized =
        rect.height * widthScale + tallPreviewMenuRoom > verticalRoom;
    final previewRoom = oversized
        ? math.max(verticalRoom - tallPreviewMenuRoom, verticalRoom / 2)
        : verticalRoom;
    final scale = rect.height > 0
        ? math.min(widthScale, previewRoom / rect.height)
        : widthScale;
    final w = rect.width * scale;
    final h = rect.height * scale;
    final left = w >= room
        ? (size.width - w) / 2
        : (rect.center.dx - w / 2).clamp(margin, size.width - margin - w);
    final maxTop = safeBottom - h;
    final top = oversized
        ? minTop
        : math.max(minTop, math.min(rect.center.dy - h / 2, maxTop));
    return Rect.fromLTWH(left, top, w, h);
  }
}
