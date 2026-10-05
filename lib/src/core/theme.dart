import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'glass_constants.dart';
import 'glass_render_mode.dart';

/// App-wide defaults for Liquid Glass. See [LiquidGlassTheme].
@immutable
class LiquidGlassThemeData {
  /// Creates theme data.
  const LiquidGlassThemeData({
    this.lightAngle = -3 * math.pi / 4,
    this.defaultGlass = Glass.regular,
    this.defaultMode = GlassRenderMode.auto,
    this.constants = GlassConstants.standard,
  });

  /// Direction toward the light, radians, y-down screen space.
  /// Default is up and to the left. Not mirrored in RTL.
  final double lightAngle;

  /// Glass used when a widget does not specify one.
  final Glass defaultGlass;

  /// Mode used when a widget does not specify one.
  ///
  /// [GlassRenderMode.auto] (the default) draws SwiftUI's own glass on
  /// iOS 26+, the shader on older iOS and Material elsewhere. Set
  /// [GlassRenderMode.shader] to keep Flutter-drawn glass everywhere.
  final GlassRenderMode defaultMode;

  /// Rendering constants fitted to SwiftUI. Override only for fidelity
  /// work; the type is exported from
  /// `package:adaptive_liquid_glass/testing.dart`.
  final GlassConstants constants;

  /// Returns a copy with the given fields replaced.
  LiquidGlassThemeData copyWith({
    double? lightAngle,
    Glass? defaultGlass,
    GlassRenderMode? defaultMode,
    GlassConstants? constants,
  }) => LiquidGlassThemeData(
    lightAngle: lightAngle ?? this.lightAngle,
    defaultGlass: defaultGlass ?? this.defaultGlass,
    defaultMode: defaultMode ?? this.defaultMode,
    constants: constants ?? this.constants,
  );

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassThemeData &&
      other.lightAngle == lightAngle &&
      other.defaultGlass == defaultGlass &&
      other.defaultMode == defaultMode &&
      other.constants == constants;

  @override
  int get hashCode =>
      Object.hash(lightAngle, defaultGlass, defaultMode, constants);
}

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
