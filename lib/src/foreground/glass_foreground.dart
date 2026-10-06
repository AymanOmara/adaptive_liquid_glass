import 'package:flutter/widgets.dart';
import '../core/glass_brightness.dart';
import '../core/glass_colors.dart';

/// Brightness of the content behind the nearest glass group.
class GlassForeground extends InheritedWidget {
  /// Creates the scope.
  const GlassForeground({
    super.key,
    required this.backgroundBrightness,
    required super.child,
  });

  /// Sampled brightness of what is behind the glass.
  final Brightness backgroundBrightness;

  /// Sampled brightness, else the glass brightness (the theme's, else the
  /// platform's; see `glassBrightnessOf`).
  static Brightness backgroundBrightnessOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassForeground>()
          ?.backgroundBrightness ??
      glassBrightnessOf(context) ??
      MediaQuery.platformBrightnessOf(context);

  /// A label colour readable on the glass.
  static Color labelColorOf(BuildContext context) =>
      backgroundBrightnessOf(context) == Brightness.light
      ? GlassColors.labelOnLight
      : GlassColors.labelOnDark;

  @override
  bool updateShouldNotify(GlassForeground old) =>
      old.backgroundBrightness != backgroundBrightness;
}
