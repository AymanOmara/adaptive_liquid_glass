import 'package:flutter/painting.dart';
import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's list swipe actions, measured from SwiftUI's `.swipeActions` in
/// a plain `List` on iPhone 17 Pro / iOS 26.4
/// (`tool/reference/controls.json`, "components" → "swipe"; tested against
/// it). Rows up to [stackedRowHeight] get compact capsules (icon and label
/// inside, 54-pt row measured); taller rows get icon-only capsules with the
/// label below (71-pt row measured). The springs, the rubber band and the
/// full-swipe point are not measured yet.
abstract final class SwipeMetrics {
  /// The gap between the row and its actions, between actions, and between
  /// the outermost action and the screen's edge.
  static const double gap = 10.33;

  /// The swiped row's platter corner radius (a circular fit of the
  /// measured corner, in both row heights).
  static const double rowRadius = 26;

  /// A compact capsule's inset from the row's top and bottom.
  static const double compactInset = 4;

  /// A compact capsule's padding either side of its icon and label
  /// (Delete 15.67, Pin 16.33 measured).
  static const double compactPadding = 16;

  /// A compact capsule's icon box (about 12 by 14 pt of SF ink).
  static const double compactIconSize = 14;

  /// The gap between a compact capsule's icon and its label.
  static const double compactIconGap = 6.67;

  /// Rows at least this tall get stacked actions. Between the two measured
  /// rows (54 and 70.67 pt): where a 40-pt capsule, its label and the
  /// insets start to fit.
  static const double stackedRowHeight = 64;

  /// A stacked capsule's size.
  static const double stackedWidth = 60;

  /// See [stackedWidth].
  static const double stackedHeight = 40;

  /// A stacked capsule's inset from the row's top.
  static const double stackedInset = 4.33;

  /// A stacked capsule's icon size.
  static const double stackedIconSize = 22;

  /// The gap between a stacked capsule and its label.
  static const double stackedLabelGap = 8;

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
  static const double fullSwipe = 0.6;

  /// How much of a drag past the actions moves the row (rubber band).
  static const double resistance = 0.3;

  /// The fling speed, in logical pixels per second, that opens or closes
  /// the row whatever its offset.
  static const double flingVelocity = 700;

  /// The row springing open or shut.
  static final SpringDescription spring = swiftUISpring(
    response: 0.35,
    dampingFraction: 0.86,
  );
}
