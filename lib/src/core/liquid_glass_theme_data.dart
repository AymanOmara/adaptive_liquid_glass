import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'glass.dart';
import 'glass_constants.dart';
import 'glass_render_mode.dart';
import 'liquid_glass_theme.dart';

const Object _unset = Object();

/// App-wide defaults for Liquid Glass. See [LiquidGlassTheme].
@immutable
class LiquidGlassThemeData {
  /// Creates theme data.
  const LiquidGlassThemeData({
    this.lightAngle = -3 * math.pi / 4,
    this.defaultGlass = Glass.regular,
    this.defaultMode = GlassRenderMode.auto,
    this.constants = GlassConstants.standard,
    this.androidShaderBudget,
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

  /// How many glass groups outside the shared glass layer may draw the
  /// shader at once on Android, per view; null (the default) removes the
  /// cap. Applies to [GlassRenderMode.shader] only (the default `auto` mode
  /// draws Material on Android) and never on iOS.
  ///
  /// Under Impeller each shader backdrop renders into full-screen
  /// offscreen textures whatever the glass's size: about 110-200 MB of GPU
  /// memory each on a 1080x2340 phone (Samsung SM-S731B, Vulkan). On
  /// Android all shader glass of a route therefore draws through one shared
  /// layer (a few passes, not one per group), and this budget only counts
  /// groups the layer cannot take: glass with no enclosing route (above the
  /// `Navigator`, in an `OverlayEntry`) or in a `GlassMenuAnchor` menu.
  /// Groups past the budget draw a frosted blur instead. A `GlassGroup`
  /// counts once whatever its members, a `LiquidGlass` outside a group
  /// counts once, and `GlassTabBar` glass is served first. The first groups
  /// to appear keep the shader; when one goes, the next waiting group takes
  /// its place on the next frame. Groups in a route hidden under an opaque
  /// route do not count.
  final int? androidShaderBudget;

  /// Returns a copy with the given fields replaced (`androidShaderBudget`
  /// takes an `int?`; pass null to remove the cap).
  LiquidGlassThemeData copyWith({
    double? lightAngle,
    Glass? defaultGlass,
    GlassRenderMode? defaultMode,
    GlassConstants? constants,
    Object? androidShaderBudget = _unset,
  }) => LiquidGlassThemeData(
    lightAngle: lightAngle ?? this.lightAngle,
    defaultGlass: defaultGlass ?? this.defaultGlass,
    defaultMode: defaultMode ?? this.defaultMode,
    constants: constants ?? this.constants,
    androidShaderBudget: identical(androidShaderBudget, _unset)
        ? this.androidShaderBudget
        : androidShaderBudget as int?,
  );

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassThemeData &&
      other.lightAngle == lightAngle &&
      other.defaultGlass == defaultGlass &&
      other.defaultMode == defaultMode &&
      other.constants == constants &&
      other.androidShaderBudget == androidShaderBudget;

  @override
  int get hashCode => Object.hash(
    lightAngle,
    defaultGlass,
    defaultMode,
    constants,
    androidShaderBudget,
  );
}
