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

  /// The least space between a centred menu and the screen's sides
  /// (estimated, not measured).
  static const double screenMargin = 16;

  /// The space between the label and the menu's trailing edge.
  static const double trailingPadding = 16;

  /// Above and below a label that wraps at larger Dynamic Type (the 42 pt
  /// row less a 17 pt line, halved).
  static const double wrappedLabelPadding = 10;

  /// The menu's padding above its first row and below its last.
  static const double verticalPadding = 10.17;

  // Sections and submenus, measured from SwiftUI's `Section` and nested
  // `Menu` (`-controls menusections`, `menusections2`, `menusubmenu`;
  // docs/superpowers/notes/menu-sections.md).

  /// A section break: the padding above the divider, the divider, the
  /// padding below it (10.17 + 1 + 10.17 between the rows around it).
  static const double dividerThickness = 1;

  /// The divider's inset from the menu's leading edge.
  static const double dividerStart = 25.67;

  /// The divider's inset from the menu's trailing edge.
  static const double dividerEnd = 24.33;

  /// A section title's size (secondary label colour).
  static const double headerFontSize = 15;

  /// A section title's block, from the menu's top padding (or the
  /// divider's) to the first row.
  static const double headerHeight = 29.67;

  /// A section title's baseline from the top of its block.
  static const double headerBaseline = 16.17;

  /// A section title's start from the menu's leading edge.
  static const double headerStart = 30;

  /// A label's start in a row without an icon, when no row of its section
  /// has one.
  static const double plainLabelStart = 31;

  /// A submenu row's chevron: its centre from the menu's trailing edge.
  static const double chevronCentreFromEnd = 30.5;

  /// The chevron's glyph size (its ink measures 6.33 × 10.67).
  static const double chevronSize = 15;

  /// How small the menu shrinks, from its top-trailing corner, while a
  /// submenu is open.
  static const double recededScale = 0.96;

  /// How much of the receded menu's content shows.
  static const double recededOpacity = 0.5;

  /// How long a submenu takes to open or close (estimated).
  static const Duration submenu = Duration(milliseconds: 300);

  /// The menu springing out of its button.
  static final SpringDescription open = swiftUISpring(
    response: 0.35,
    dampingFraction: 0.8,
  );

  /// How long the menu takes to fade away.
  static const Duration close = Duration(milliseconds: 150);
}
