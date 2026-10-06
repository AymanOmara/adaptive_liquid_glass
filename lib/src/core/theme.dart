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
///
/// An [InheritedTheme], so themes captured around the presenting context
/// (as overlays do) carry it into the pushed page.
class LiquidGlassTheme extends InheritedTheme {
  /// Creates a theme scope.
  const LiquidGlassTheme({super.key, required this.data, required super.child});

  /// The theme data.
  final LiquidGlassThemeData data;

  /// Nearest theme data, or the defaults.
  static LiquidGlassThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidGlassTheme>()?.data ??
      const LiquidGlassThemeData();

  @override
  Widget wrap(BuildContext context, Widget child) =>
      LiquidGlassTheme(data: data, child: child);

  @override
  bool updateShouldNotify(LiquidGlassTheme oldWidget) => data != oldWidget.data;
}
