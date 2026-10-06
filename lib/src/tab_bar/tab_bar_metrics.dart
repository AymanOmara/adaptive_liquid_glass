import 'package:flutter/cupertino.dart';

import '../core/swiftui_spring.dart';

/// Measured from iOS 26.4's tab bar (Kept, iPhone 17 Pro) by frame-by-frame
/// tracking of press, hold, drag and release (`example/lib/tab_bar_probe.dart`
/// lays the bar out the same way).
abstract final class TabBarMetrics {
  /// The gap between the bar's edge and its tabs.
  static const double inset = 4;

  /// How much wider than the tab spacing the pill is (93.7 over 86.15).
  static const double pillExtra = 7.55;

  /// The held lens over the pill: 114.3 by 74 against 93.7 by 54.
  static const double lensGrowX = 20.6;

  /// See [lensGrowX].
  static const double lensGrowY = 20;

  /// The lens sits 1.06 times as far from the bar's centre as the finger,
  /// up to this far past the outermost tab.
  static const double lensGain = 1.06;

  /// See [lensGain].
  static const double lensReach = 7.1;

  /// While held the bar grows this much on each side, plus [growLean] of
  /// the lens's offset from the centre towards the lens.
  static const double growX = 9.15;

  /// See [growX].
  static const double growY = 1.65;

  /// See [growX].
  static const double growLean = 0.0237;

  /// Tabs under the lens are magnified about their own centres (Kept).
  static const double magnifyX = 1.21;

  /// See [magnifyX].
  static const double magnifyY = 1.19;

  /// Peak white of the light a held lens casts on the bar (see BarGlow).
  static const double glow = 0.095;

  /// The bar's light coming on (press, drag) and fading after release
  /// (Kept: about a third left 16 frames after letting go).
  static final SpringDescription light = swiftUISpring(
    response: 0.3,
    dampingFraction: 1,
  );

  /// See [light].
  static final SpringDescription lightOff = swiftUISpring(
    response: 0.45,
    dampingFraction: 1,
  );

  /// The band at the lens's edge where content is refracted, not sharp.
  static const double lensRim = 9;

  /// The lens's height wobbles with its sideways acceleration (taller when
  /// it accelerates to the left), as a damped oscillator: points of extra
  /// overhang per side per pt/s² of acceleration.
  static const double wobbleGain = 0.002607;

  /// The wobble's oscillator; see [wobbleGain].
  static final SpringDescription wobble = swiftUISpring(
    response: 1.159,
    dampingFraction: 0.499,
  );

  /// A tab's icon size.
  static const double iconSize = 26;

  /// The gap between a tab's icon and its label.
  static const double labelGap = 2;

  /// A tab's label.
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  /// A text badge's height (and least width).
  static const double badgeHeight = 18;

  /// An empty badge's diameter.
  static const double badgeDot = 10;

  /// A text badge's text.
  static const TextStyle badge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1,
  );

  /// Pill to lens.
  static final SpringDescription press = swiftUISpring(
    response: 0.381,
    dampingFraction: 0.752,
  );

  /// Lens back to pill (it undershoots: the pill squashes).
  static final SpringDescription release = swiftUISpring(
    response: 0.27,
    dampingFraction: 0.55,
  );

  /// The lens following the finger.
  static final SpringDescription follow = swiftUISpring(
    response: 0.35,
    dampingFraction: 1.0,
  );

  /// The lens travelling from the selection to a pressed or tapped tab:
  /// History to Settings arrives in ~11 frames on iOS 26.4 (Kept).
  static final SpringDescription travel = swiftUISpring(
    response: 0.22,
    dampingFraction: 0.85,
  );

  /// The pill moving to a newly selected tab.
  static final SpringDescription slide = swiftUISpring(
    response: 0.3,
    dampingFraction: 0.78,
  );
}
