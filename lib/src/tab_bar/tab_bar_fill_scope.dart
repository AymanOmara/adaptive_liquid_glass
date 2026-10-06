import 'package:flutter/widgets.dart';

/// Makes a `GlassTabBar` below fill the width it is given, spreading its
/// tabs. iOS 26 widens the tab bar to its bottom accessory's width
/// (measured: 274 pt alone, 360 with an accessory, iPhone 17 Pro);
/// `GlassScaffold` uses this when it has a bottom accessory.
class TabBarFillScope extends InheritedWidget {
  /// Creates the scope.
  const TabBarFillScope({super.key, required super.child});

  /// Whether a tab bar at [context] fills its width.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabBarFillScope>() != null;

  @override
  bool updateShouldNotify(TabBarFillScope old) => false;
}
