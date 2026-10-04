import 'package:flutter/widgets.dart';

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

  /// Sampled brightness, else the platform brightness.
  static Brightness backgroundBrightnessOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<GlassForeground>()
          ?.backgroundBrightness ??
      MediaQuery.platformBrightnessOf(context);

  /// A label colour readable on the glass.
  static Color labelColorOf(BuildContext context) =>
      backgroundBrightnessOf(context) == Brightness.light
      ? const Color(0xD9000000)
      : const Color(0xFFFFFFFF);

  @override
  bool updateShouldNotify(GlassForeground old) =>
      old.backgroundBrightness != backgroundBrightness;
}
