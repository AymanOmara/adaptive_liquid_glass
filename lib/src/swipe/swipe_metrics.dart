import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's list swipe actions, measured from SwiftUI's `.swipeActions` in
/// a plain `List` on iPhone 17 Pro / iOS 26.4
/// (`tool/reference/controls.json`, "components" → "swipe"; tested against
/// it). Rows up to [stackedRowHeight] get compact capsules (icon and label
/// inside, 54-pt row measured); taller rows get icon-only capsules with the
/// label below (71-pt row measured), or a circle (110-pt row measured).
/// The motion is measured frame by frame from the same scenes
/// (`tool/fidelity/record_swipe_motion.sh`, `swipe_motion.py`).
abstract final class SwipeMetrics {
  /// The gap between the row and its actions, between actions, and between
  /// the outermost action and the screen's edge.
  static const double gap = 10.33;

  /// The swiped row's platter corner radius (a circular fit of the
  /// measured corner, in both row heights).
  static const double rowRadius = 26;

  /// A compact capsule's inset from the row's top and bottom.
  static const double compactInset = 4;

  /// A compact capsule's padding either side of its icon and label's ink
  /// (Delete 15.67, Pin 16.33 measured).
  static const double compactPadding = 16;

  /// How much of the padding the label's side bearing already gives, each
  /// side: its advance is wider than its ink (87-pt Delete and Share,
  /// 67-pt Pin measured).
  static const double compactLabelBearing = 1.85;

  /// A compact capsule's icon glyph size.
  static const double compactIconSize = 14;

  /// The width a compact capsule gives its icon: SF's ink is about 12 pt
  /// wide with no side bearing, so the glyph's own margins are not laid
  /// out.
  static const double compactIconWidth = 12;

  /// The gap between a compact capsule's icon and its label.
  static const double compactIconGap = 6.5;

  /// Rows at least this tall get stacked actions. Between the two measured
  /// rows (54 and 70.67 pt): where a 40-pt capsule, its label and the
  /// insets start to fit.
  static const double stackedRowHeight = 64;

  /// Rows at least this tall get [stackedCircle]s, centred with their
  /// labels; shorter stacked rows get 60 x 40 capsules at the top.
  /// Between the measured 70.67-pt row (capsules, one or two actions) and
  /// the 110-pt row (circles, one or two actions).
  static const double circleRowHeight = 90;

  /// A stacked capsule's size.
  static const double stackedWidth = 60;

  /// See [stackedWidth].
  static const double stackedHeight = 40;

  /// A stacked capsule's inset from the row's top.
  static const double stackedInset = 4.33;

  /// A stacked action's circle in a tall row (see [circleRowHeight]).
  static const double stackedCircle = 50;

  /// The gap between a circle and its label.
  static const double circleLabelGap = 7.4;

  /// A stacked capsule's icon size.
  static const double stackedIconSize = 22;

  /// The gap between a stacked capsule and its label.
  static const double stackedLabelGap = 8;

  /// The label's line, for centring a circle and its label in the row.
  static const double stackedLabelHeight = 14;

  /// How far a 13-pt label's ink starts below its line box's top.
  static const double labelInkTop = 4.4;

  /// An action's label (white in a compact capsule; secondary label colour
  /// under a stacked one): 13 pt.
  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    // iOS's tracking at 13 pt (see IOSText).
    letterSpacing: -0.08,
  );

  /// The fraction of the row's width past which a swipe runs the
  /// edge-most action.
  static const double fullSwipe = 0.62;

  /// How much of a drag past the actions moves the row (rubber band),
  /// without full swipe.
  static const double resistance = 0.3;

  /// Finger travel dropped past the touch slop before a row at rest
  /// moves: SwiftUI drops about 26 in all, the recognizer 18.
  static const double dragSlack = 8;

  /// The outward speed (pt/s) past [fullSwipe] at which the first action
  /// takes the row; slower, the row only opens (SwiftUI: a 134 pt/s pull
  /// to 0.77 of the width reopens, a flick takes it at 0.62).
  static const double fullSwipeVelocity = 300;

  /// The fling speed, in logical pixels per second, that opens or closes
  /// the row whatever its offset.
  static const double flingVelocity = 300;

  /// How far past the full uncovering of the slot before it (or of the
  /// edge gap, for the outermost action) an action starts to grow: it
  /// grows in place, at its resting centre, from nothing to full size
  /// as its own slot (the action and the gap by the row) is uncovered.
  /// The outermost shows from about 48 pt; the next from its slot + 38.
  static const double revealLead = 38;

  /// An action's opacity as it starts to grow; opaque at full size.
  static const double revealOpacity = 0.213;

  /// Past the resting offset the inner actions keep to the row and fade:
  /// quickly to about [innerFade], then by [innerFadeTail] more over the
  /// next 60 pt; they vanish at the full-swipe point (0.64 at +20 pt,
  /// 0.61 at +40, 0.54 at +80 measured).
  static const double innerFade = 0.62;

  /// The distance over which the quick part of the fade falls by 1/e.
  static const double innerFadeDistance = 8;

  /// The slow part of the fade, from +20 to +80 pt past rest.
  static const double innerFadeTail = 0.08;

  /// The time constant by which an action's size trails the size the
  /// offset sets (fitted with [growRate] over every recorded drag:
  /// `tool/fidelity/swipe_fit.py`).
  static const double growLag = 0.028;

  /// The fastest an action grows or shrinks, in sizes per second: a fast
  /// drag outruns it (SwiftUI climbs about 0.073 a frame on any fast
  /// drag).
  static const double growRate = 4.7;

  /// The actions shrinking and fading together, linearly, as the row
  /// closes, from the tap or release (gone by about 12 frames measured).
  static const Duration closeFade = Duration(milliseconds: 200);

  /// The opacity the actions fade to as they shrink away closing (0.98 to
  /// 0.44 measured).
  static const double closeOpacity = 0.4;

  /// The part of [closeFade] the inner actions take to go (about 85 of
  /// 200 ms measured).
  static const double innerCloseFraction = 0.43;

  /// How far, as a fraction of the actions' extent, a let-go row must be
  /// open to spring open (it opened from 47% measured).
  static const double openFraction = 0.4;

  /// The time constant of the row's platter fading in from the drag's
  /// start (and out from the close's, from the tap or release): it is
  /// not tied to the offset. The corner radius follows it.
  static const double platterTau = 0.15;

  /// How long the platter's fade runs (it is within 1% by then).
  static const Duration platterFade = Duration(milliseconds: 740);

  /// A destructive full swipe's row collapsing from the takeover, with
  /// no delay (fits of response 0.28 to 0.31, damping 0.87 to 0.98).
  static final SpringDescription collapse = swiftUISpring(
    response: 0.31,
    dampingFraction: 0.88,
  );

  /// The bounce of an action as its size reaches full: a spring about
  /// full size, starting at [bounceCarry] of the growth's speed there
  /// (peaks of 1.014 to 1.043 measured, 2 to 5 frames on).
  static final SpringDescription bounce = swiftUISpring(
    response: 0.5,
    dampingFraction: 0.75,
  );

  /// The least speed (sizes per second) an action grows at towards its
  /// size while the row springs open: SwiftUI's runs through full size,
  /// not easing in.
  static const double openGrowFloor = 1;

  /// The same while dragged, as a share of the drag's smoothed speed
  /// along the action's growth ramp (ramps per second).
  static const double dragGrowFloor = 0.1;

  /// The time constant (s) the ramp speed is smoothed over.
  static const double rampSpeedTime = 0.02;

  /// The most ramp speed [dragGrowFloor] takes.
  static const double rampSpeedMax = 5;

  /// The share of the growth's speed the [bounce] starts with.
  static const double bounceCarry = 1.1;

  /// How far out, as a fraction of the width, a destructive full swipe's
  /// row jumps at the release (0.885 and 0.92 measured).
  static const double exitJump = 0.9;

  /// The row gliding on out from there, the action following
  /// (response 0.17 to 0.23 fitted).
  static final SpringDescription exitSpring = swiftUISpring(
    response: 0.2,
    dampingFraction: 1,
  );

  /// The glide's starting speed, in points per second (600 to 690
  /// fitted).
  static const double exitVelocity = 650;

  /// The row springing open or shut: critically damped, no overshoot
  /// (fits of response 0.43 to 0.49, damping 1.02 to 1.09).
  static final SpringDescription spring = swiftUISpring(
    response: 0.48,
    dampingFraction: 1,
  );
}
