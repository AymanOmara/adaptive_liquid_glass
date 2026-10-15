import 'package:flutter/widgets.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_effective_path.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';

/// Shows [glass] on the glass paths and your own [material] widget on the
/// Material path, so app code never checks the platform.
///
/// ```dart
/// GlassAdaptive(
///   glass: GlassTabBar(items: items, selectedIndex: i, onSelected: pick),
///   material: (context) => NavigationBar(
///     selectedIndex: i,
///     onDestinationSelected: pick,
///     destinations: destinations,
///   ),
/// )
/// ```
///
/// The choice follows the rendering mode [mode] resolves to (the theme's
/// default when null), not the platform: native, shader, degraded and
/// opaque all show [glass].
class GlassAdaptive extends StatelessWidget {
  /// Creates the switch.
  const GlassAdaptive({
    super.key,
    required this.glass,
    required this.material,
    this.mode,
  });

  /// Shown on every path but Material.
  final Widget glass;

  /// Builds the widget shown on the Material path.
  final WidgetBuilder material;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The path a glass widget with [mode] (the theme's default when null)
  /// takes at [context], resolved exactly as [GlassAdaptive] and every glass
  /// widget resolve it, for function-style APIs:
  ///
  /// ```dart
  /// Navigator.of(context).push(
  ///   GlassAdaptive.usesGlass(context)
  ///       ? CupertinoPageRoute(builder: buildPage)
  ///       : MaterialPageRoute(builder: buildPage),
  /// );
  /// ```
  ///
  /// It reads the platform environment as it is now; a widget that must
  /// follow live changes (Reduce Transparency, say) builds through
  /// [GlassAdaptive] instead.
  static GlassEffectivePath pathOf(
    BuildContext context, {
    GlassRenderMode? mode,
  }) => glassEffectivePathOf(resolveGlassModeOf(context, mode: mode));

  /// Whether [pathOf] is a glass path, that is, whether [GlassAdaptive]
  /// would show its `glass` widget.
  static bool usesGlass(BuildContext context, {GlassRenderMode? mode}) =>
      pathOf(context, mode: mode).isGlass;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) =>
        effective == EffectiveGlassMode.material ? material(context) : glass,
  );
}
