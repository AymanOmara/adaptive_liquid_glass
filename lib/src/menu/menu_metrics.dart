import 'package:flutter/physics.dart';

import '../core/swiftui_spring.dart';

/// iOS 26's pull-down menu. Approximate: read from iOS 26.4 screenshots,
/// not yet fitted against SwiftUI scenes.
abstract final class MenuMetrics {
  /// The menu's width.
  static const double width = 250;

  /// The menu's corner radius.
  static const double cornerRadius = 26;

  /// A row's height.
  static const double rowHeight = 44;

  /// A row's label size.
  static const double fontSize = 17;

  /// A row's icon size.
  static const double iconSize = 20;

  /// The menu's horizontal padding inside each row.
  static const double rowPadding = 16;

  /// The menu's gap from its button.
  static const double gap = 8;

  /// The menu's vertical padding around its rows.
  static const double verticalPadding = 6;

  /// The menu springing out of its button.
  static final SpringDescription open = swiftUISpring(
    response: 0.35,
    dampingFraction: 0.8,
  );

  /// How long the menu takes to fade away.
  static const Duration close = Duration(milliseconds: 150);
}
