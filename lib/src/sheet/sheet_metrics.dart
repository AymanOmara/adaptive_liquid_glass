import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's sheet, measured from SwiftUI's `.sheet` with
/// `.presentationDetents([.medium])` and `([.large])` on iPhone 17 Pro /
/// iOS 26.4 (`tool/reference/controls.json`, "components" → "sheet";
/// tested against it). At the medium detent it is glass floating in from
/// the screen's edges; at the large detent it runs edge to edge, opaque,
/// with the screen's own corners at the bottom.
abstract final class SheetMetrics {
  /// The floating sheet's inset from the screen's sides and bottom.
  static const double inset = 8;

  /// The floating sheet's corner radius (circular fit 38).
  static const double cornerRadius = 38;

  /// The large sheet's top corner radius (circular fit 42).
  static const double largeTopRadius = 42;

  /// The large sheet's bottom corner radius: the screen's own corners
  /// (iPhone 17 Pro).
  static const double largeBottomRadius = 62;

  /// The medium detent: the sheet's top edge this fraction of the screen's
  /// height above its bottom (459 of 874 pt).
  static const double mediumFraction = 459 / 874;

  /// The grabber.
  static const double grabberWidth = 34.67;

  /// See [grabberWidth].
  static const double grabberHeight = 5;

  /// The grabber's gap from the sheet's top edge.
  static const double grabberTop = 4.67;

  /// How far below its lowest detent a released sheet is dismissed, as a
  /// fraction of that detent's height.
  static const double dismissFraction = 0.25;

  /// The fling speed, in logical pixels per second, that moves a sheet to
  /// the next detent (or dismisses it).
  static const double flingVelocity = 700;

  /// The sheet settling on a detent.
  static final SpringDescription spring = swiftUISpring(
    response: 0.4,
    dampingFraction: 0.86,
  );
}
