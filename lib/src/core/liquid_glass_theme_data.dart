import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../native/glass_batch.dart';

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
    this.supportLiquidGlassOnAndroid = false,
    this.batchImplicitGroups = false,
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

  /// How many glass groups outside the shared glass layer may draw the
  /// shader at once on Android, per view; null (the default) removes the
  /// cap. Applies whenever the shader glass is drawn on Android
  /// ([GlassRenderMode.shader], or `auto` with
  /// [supportLiquidGlassOnAndroid]) and never on iOS.
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

  /// Whether glass that would get a native view of its own on iOS 26+
  /// shares one with its neighbours. Off by default.
  ///
  /// On iOS 26 a `LiquidGlass` outside any `GlassGroup` gets a group of its
  /// own, and every group hosts one native (SwiftUI) platform view, which
  /// is slow to create: a sheet with 29 bare chips stalls for about a
  /// second. With this on:
  ///
  /// * `GlassSheet` content and `GlassScaffold` bodies host a [GlassBatch]
  ///   automatically: their ungrouped glass draws in one native view.
  /// * A `GlassGroup` on the native path takes any number of members (the
  ///   16-shape cap only binds the shader); without this, members past the
  ///   16th get native views of their own.
  ///
  /// A [GlassBatch] placed by the app works whether this is on or off. Glass
  /// inside a scroll view joins a batch only when the batch is inside that
  /// scroll view too, so for scrolling content put a [GlassBatch] around
  /// the scrolled content yourself; see [GlassBatch] for what else keeps
  /// glass out of a batch. Shader, Material and degraded glass are not
  /// affected.
  final bool batchImplicitGroups;

  /// Returns a copy with the given fields replaced (`androidShaderBudget`
  /// takes an `int?`; pass null to remove the cap).
  LiquidGlassThemeData copyWith({
    double? lightAngle,
    Glass? defaultGlass,
    GlassRenderMode? defaultMode,
    GlassConstants? constants,
    Object? androidShaderBudget = _unset,
    bool? supportLiquidGlassOnAndroid,
    bool? batchImplicitGroups,
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
    batchImplicitGroups: batchImplicitGroups ?? this.batchImplicitGroups,
  );

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassThemeData &&
      other.lightAngle == lightAngle &&
      other.defaultGlass == defaultGlass &&
      other.defaultMode == defaultMode &&
      other.constants == constants &&
      other.androidShaderBudget == androidShaderBudget &&
      other.supportLiquidGlassOnAndroid == supportLiquidGlassOnAndroid &&
      other.batchImplicitGroups == batchImplicitGroups;

  @override
  int get hashCode => Object.hash(
    lightAngle,
    defaultGlass,
    defaultMode,
    constants,
    androidShaderBudget,
    supportLiquidGlassOnAndroid,
    batchImplicitGroups,
  );
}
