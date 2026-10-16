import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's context menu, measured from UIKit's UIContextMenuInteraction
/// (what SwiftUI's `.contextMenu` rides on) on iPhone 17 Pro / iOS 26.4,
/// opened programmatically in the reference harness (`-controls
/// contextmenuuikit`, `…left`, `…wide`; "components" → "context_menu" in
/// tool/reference/controls.json). Synthetic touches still do not open
/// SwiftUI's own. The menu itself is the measured glass menu
/// (`MenuMetrics`). The page behind is dimmed (`GlassColors
/// .contextMenuBarrier`) but not blurred: over 100-pt black and white
/// stripes its edges stay one pixel sharp (`-controls
/// contextmenuuikitstripes`).
abstract final class ContextMenuMetrics {
  // Motion, fitted from 60 fps frame dumps of UIKit's menu opening and
  // closing (`-controls contextmenuuikitmotion`, a tap opens it and a
  // second closes it; tool/fidelity/record_component_motion.sh).

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

  /// Where an item at [rect] sits lifted on a screen of [size]: grown by
  /// [lift] about its centre, less when it would not fit between the
  /// [margin]s, then shifted inside them, as UIKit does.
  static Rect lifted(Rect rect, Size size) {
    final room = size.width - 2 * margin;
    final scale = rect.width <= 0
        ? lift
        : math.max(1.0, math.min(lift, room / rect.width));
    final w = rect.width * scale;
    final h = rect.height * scale;
    final left = w >= room
        ? (size.width - w) / 2
        : (rect.center.dx - w / 2).clamp(margin, size.width - margin - w);
    return Rect.fromLTWH(left, rect.center.dy - h / 2, w, h);
  }
}
