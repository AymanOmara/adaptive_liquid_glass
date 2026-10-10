import 'package:flutter/widgets.dart';

import '../core/effective_glass_mode.dart';
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

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) =>
        effective == EffectiveGlassMode.material ? material(context) : glass,
  );
}
