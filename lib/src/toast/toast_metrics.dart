import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// The toast's metrics. iOS has no public toast API, so every value here
/// is estimated in its spirit (a glass capsule at the top, like the
/// notification shelf), not measured from SwiftUI.
abstract final class ToastMetrics {
  /// The capsule's gap below the top safe area.
  static const double topGap = 8;

  /// The capsule's inset from the screen's sides.
  static const double sideInset = 16;

  /// The capsule's widest width.
  static const double maxWidth = 500;

  /// The capsule's shortest height.
  static const double minHeight = 48;

  /// The content's inset from the capsule's top and bottom, so a
  /// two-line message clears the corners.
  static const double verticalPadding = 8;

  /// The content's inset from the capsule's start.
  static const double startPadding = 20;

  /// The content's inset from the capsule's end without an action.
  static const double endPadding = 20;

  /// The content's inset from the capsule's end with an action (the
  /// action brings its own).
  static const double actionEndPadding = 8;

  /// The icon's size.
  static const double iconSize = 20;

  /// The gap between the icon and the message.
  static const double iconGap = 10;

  /// The message's text size.
  static const double fontSize = 15;

  /// The gap between the message and the action.
  static const double actionGap = 12;

  /// Touch padding around the action's label.
  static const double actionPadding = 8;

  /// The message's most lines.
  static const int maxLines = 2;

  /// The upward drag (towards the screen edge) that dismisses.
  static const double dismissDistance = 24;

  /// The fling speed, in logical pixels per second towards the screen
  /// edge, that dismisses.
  static const double dismissVelocity = 300;

  /// The fraction of a drag away from the screen edge that moves the
  /// capsule.
  static const double dragResistance = 0.2;

  /// The capsule sliding in.
  static final SpringDescription enter = swiftUISpring(
    response: 0.45,
    dampingFraction: 0.8,
  );

  /// The capsule leaving.
  static final SpringDescription exit = swiftUISpring(
    response: 0.35,
    dampingFraction: 1,
  );

  /// The Reduce Motion cross fade.
  static const Duration fadeDuration = Duration(milliseconds: 200);

  /// How long a toast stays by default.
  static const Duration defaultDuration = Duration(seconds: 4);

  /// The Material surface's inset from the screen's sides and bottom.
  static const double materialInset = 16;

  /// The Material surface's corner radius.
  static const double materialRadius = 4;

  /// The Material surface's elevation.
  static const double materialElevation = 6;

  /// The Material content's inset from the start.
  static const double materialStartPadding = 16;

  /// The Material content's inset from the end with an action.
  static const double materialEndPadding = 8;

  /// The Material content's vertical padding.
  static const double materialVerticalPadding = 14;
}
