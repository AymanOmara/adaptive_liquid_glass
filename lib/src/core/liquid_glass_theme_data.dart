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
    this.androidShaderBudget = 4,
    this.supportLiquidGlassOnAndroid = false,
  });

  /// Direction toward the light, radians, y-down screen space.
  /// Default is up and to the left. Not mirrored in RTL.
  final double lightAngle;

  /// Glass used when a widget does not specify one.
  final Glass defaultGlass;

  /// Mode used when a widget does not specify one.
  ///
  /// [GlassRenderMode.auto] (the default) draws SwiftUI's own glass on
  /// iOS 26+, the shader on older iOS and Material elsewhere (shader glass
  /// on Android with [supportLiquidGlassOnAndroid]). Set
  /// [GlassRenderMode.shader] to keep Flutter-drawn glass everywhere.
  final GlassRenderMode defaultMode;

  /// Rendering constants fitted to SwiftUI. Override only for fidelity
  /// work; the type is exported from
  /// `package:adaptive_liquid_glass/testing.dart`.
  final GlassConstants constants;

  /// How many glass groups may draw the shader at once on Android, per
  /// view; null removes the cap. Applies whenever the shader glass is drawn
  /// on Android ([GlassRenderMode.shader], or `auto` with
  /// [supportLiquidGlassOnAndroid]) and never on iOS.
  ///
  /// Under Impeller each shader glass group renders into full-screen
  /// offscreen textures whatever the glass's size: about 110-200 MB of GPU
  /// memory per group on a 1080x2340 phone, measured on a Samsung
  /// SM-S731B (Vulkan), and enough groups get the app killed by Android's
  /// low-memory killer. Groups past the budget draw a frosted blur
  /// instead. A `GlassGroup` counts once whatever its members, a
  /// `LiquidGlass` outside a group counts once, and `GlassTabBar` glass is
  /// served first. The first groups to appear keep the shader; when one
  /// goes, the next waiting group takes its place on the next frame.
  /// Groups in a route hidden under an opaque route do not count.
  final int? androidShaderBudget;

  /// Whether [GlassRenderMode.auto] draws the iOS Liquid Glass look on
  /// Android (the package's shader glass) instead of Material 3. Off by
  /// default.
  ///
  /// The simple switch for Android: leave [defaultMode] at `auto` and set
  /// this. iOS is unchanged (SwiftUI's glass on 26+, the shader below),
  /// and other platforms (web, desktop) keep Material. Where the device
  /// cannot run the shader (`ImageFilter.isShaderFilterSupported` false,
  /// i.e. not Impeller) the glass draws a frosted blur instead. A
  /// widget's own `mode:`, or a [defaultMode] other than `auto`, still
  /// wins.
  ///
  /// The shader loads on first use, so the first frame or two of glass
  /// draw a plain blur; to have it ready before the first frame, call
  /// `AdaptiveLiquidGlass.initialize(supportLiquidGlassOnAndroid: true)`
  /// in `main()`. Each shader glass group costs 110-200 MB of GPU memory
  /// on Android, so [androidShaderBudget] caps how many draw at once.
  final bool supportLiquidGlassOnAndroid;

  /// Returns a copy with the given fields replaced (`androidShaderBudget`
  /// takes an `int?`; pass null to remove the cap).
  LiquidGlassThemeData copyWith({
    double? lightAngle,
    Glass? defaultGlass,
    GlassRenderMode? defaultMode,
    GlassConstants? constants,
    Object? androidShaderBudget = _unset,
    bool? supportLiquidGlassOnAndroid,
  }) => LiquidGlassThemeData(
    lightAngle: lightAngle ?? this.lightAngle,
    defaultGlass: defaultGlass ?? this.defaultGlass,
    defaultMode: defaultMode ?? this.defaultMode,
    constants: constants ?? this.constants,
    androidShaderBudget: identical(androidShaderBudget, _unset)
        ? this.androidShaderBudget
        : androidShaderBudget as int?,
    supportLiquidGlassOnAndroid:
        supportLiquidGlassOnAndroid ?? this.supportLiquidGlassOnAndroid,
  );

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassThemeData &&
      other.lightAngle == lightAngle &&
      other.defaultGlass == defaultGlass &&
      other.defaultMode == defaultMode &&
      other.constants == constants &&
      other.androidShaderBudget == androidShaderBudget &&
      other.supportLiquidGlassOnAndroid == supportLiquidGlassOnAndroid;

  @override
  int get hashCode => Object.hash(
    lightAngle,
    defaultGlass,
    defaultMode,
    constants,
    androidShaderBudget,
    supportLiquidGlassOnAndroid,
  );
}
