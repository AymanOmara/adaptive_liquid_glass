import 'package:flutter/widgets.dart';

import '../core/glass_brightness.dart';
import '../core/glass_constants.dart';
import '../core/glass_render_mode.dart';
import 'glass_member_rendering.dart';
import 'glass_registry.dart';

/// Shares a group's registry and resolved mode with its members.
class GlassGroupScope extends InheritedWidget {
  /// Creates the scope.
  const GlassGroupScope({
    super.key,
    required this.registry,
    required this.rendering,
    required this.constants,
    required this.opaqueColor,
    required this.brightness,
    required this.settled,
    required this.requestedMode,
    this.scrollable,
    required super.child,
  });

  /// The group's registry.
  final GlassRegistry registry;

  /// How members render.
  final GlassMemberRendering rendering;

  /// Constants.
  final GlassConstants constants;

  /// Reduce Transparency fill.
  final Color? opaqueColor;

  /// The brightness member surfaces draw with; null without a `MediaQuery`.
  ///
  /// Resolved once per group build; see [GlassGroupScope.maybeBrightnessOf].
  final Brightness? brightness;

  /// True after the group's first frame (members added later may animate in).
  final bool settled;

  /// The group's requested mode, reused for overflow groups.
  final GlassRenderMode? requestedMode;

  /// The nearest `Scrollable` enclosing the group, or null.
  ///
  /// The group repaints when it or any outer scrollable moves. Members
  /// listen to the scrollables between themselves and this one.
  final ScrollableState? scrollable;

  /// Nearest scope or null.
  static GlassGroupScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassGroupScope>();

  /// Nearest scope; asserts one exists.
  static GlassGroupScope of(BuildContext context) => maybeOf(context)!;

  /// The brightness glass surfaces draw with, or null without a
  /// `MediaQuery` in scope.
  ///
  /// Inside a group this is resolved once per build by `GlassGroup.build`
  /// with `glassBrightnessOf` (the theme's brightness, else the platform's),
  /// so the shader, degraded, loading and native paths all agree with each
  /// other and with the Cupertino colours of the content; outside one, the
  /// same rule from the ambient theme and `MediaQuery`.
  ///
  /// Without any brightness at all the surfaces differ on purpose: the
  /// degraded and loading surfaces throw (see [brightnessOf], like the
  /// direct `MediaQuery` reads they replace), while the native layer falls
  /// back to [Brightness.light] — it must always send an appearance flag
  /// to its platform view, and drawing light was its behaviour before this
  /// scope existed.
  static Brightness? maybeBrightnessOf(BuildContext context) =>
      maybeOf(context)?.brightness ?? glassBrightnessOf(context);

  /// [maybeBrightnessOf] for surfaces that draw a brightness-dependent look
  /// and require one.
  static Brightness brightnessOf(BuildContext context) =>
      maybeBrightnessOf(context) ?? MediaQuery.platformBrightnessOf(context);

  @override
  bool updateShouldNotify(GlassGroupScope old) =>
      old.registry != registry ||
      old.rendering != rendering ||
      old.constants != constants ||
      old.opaqueColor != opaqueColor ||
      old.brightness != brightness ||
      old.settled != settled ||
      old.requestedMode != requestedMode ||
      old.scrollable != scrollable;
}
