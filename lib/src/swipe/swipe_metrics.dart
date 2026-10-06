import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's list swipe actions. Approximate: read from iOS 26.4 screen
/// recordings, not yet fitted against SwiftUI scenes.
abstract final class SwipeMetrics {
  /// Each action's share of the opened width.
  static const double actionExtent = 74;

  /// The gap between the row and its actions, and between actions.
  static const double gap = 8;

  /// An action capsule's height.
  static const double capsuleHeight = 36;

  /// An action's icon size.
  static const double iconSize = 20;

  /// The gap between a capsule and its label.
  static const double labelGap = 4;

  /// An action's label size.
  static const double labelSize = 12;

  /// An action's height, capsule and label; shorter rows scale it down.
  static const double actionHeight = 56;

  /// The swiped row's corner radius.
  static const double rowRadius = 22;

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
