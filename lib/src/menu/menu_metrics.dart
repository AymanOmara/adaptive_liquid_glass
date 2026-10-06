import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's pull-down menu, measured from SwiftUI's `Menu` on iPhone 17
/// Pro / iOS 26.4 (`tool/reference/controls.json`, "components" → "menu";
/// tested against it). It opens over its button: the menu's top and
/// trailing edges line up with the button's. The opening spring is not
/// measured yet.
abstract final class MenuMetrics {
  /// The menu's width.
  static const double width = 252;

  /// The menu's corner radius (continuous corners; a circular fit of the
  /// measured corner gives 32).
  static const double cornerRadius = 32;

  /// The distance between rows.
  static const double rowHeight = 42;

  /// A row's label size.
  static const double fontSize = 17;

  /// A row's icon size.
  static const double iconSize = 20;

  /// The icon's centre from the menu's leading edge.
  static const double iconCentre = 41;

  /// The label's start from the menu's leading edge.
  static const double labelStart = 66;

  /// In a menu of choices, the checkmark's centre from the leading edge.
  static const double checkCentre = 29;

  /// In a menu of choices, the label's start from the leading edge.
  static const double checkLabelStart = 44.67;

  /// The checkmark's size.
  static const double checkSize = 15;

  /// A picker's menu opens with its top this far above the picker's
  /// centre.
  static const double pickerOffset = 19;

  /// The space between the label and the menu's trailing edge.
  static const double trailingPadding = 16;

  /// The menu's padding above its first row and below its last.
  static const double verticalPadding = 10.17;

  /// The menu springing out of its button.
  static final SpringDescription open = swiftUISpring(
    response: 0.35,
    dampingFraction: 0.8,
  );

  /// How long the menu takes to fade away.
  static const Duration close = Duration(milliseconds: 150);
}
