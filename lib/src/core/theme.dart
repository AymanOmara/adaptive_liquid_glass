import 'package:flutter/widgets.dart';

import 'liquid_glass_theme_data.dart';

/// Provides [LiquidGlassThemeData] to descendants. Optional: without one,
/// the defaults apply.
///
/// ```dart
/// LiquidGlassTheme(
///   data: const LiquidGlassThemeData(
///     defaultGlass: Glass.clear,
///   ),
///   child: MaterialApp(home: const HomePage()),
/// )
/// ```
class LiquidGlassTheme extends InheritedWidget {
  /// Creates a theme scope.
  const LiquidGlassTheme({super.key, required this.data, required super.child});

  /// The theme data.
  final LiquidGlassThemeData data;

  /// Nearest theme data, or the defaults.
  static LiquidGlassThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidGlassTheme>()?.data ??
      const LiquidGlassThemeData();

  @override
  bool updateShouldNotify(LiquidGlassTheme oldWidget) => data != oldWidget.data;
}
