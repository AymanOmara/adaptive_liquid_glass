import 'package:flutter/widgets.dart';

import '../core/effective_glass_mode.dart';
import '../core/liquid_glass_theme.dart';
import '../core/render_mode_resolver.dart';
import '../platform/glass_platform.dart';
import 'glass_material_tab_bar_style.dart';
import 'glass_tab_bar.dart';

/// Whether [bar] draws as Material's full-width navigation bar at
/// [context]: [GlassMaterialTabBarStyle.edgeToEdge] on the Material path.
bool tabBarEdgeToEdge(BuildContext context, GlassTabBar bar) =>
    bar.materialStyle == GlassMaterialTabBarStyle.edgeToEdge &&
    resolveGlassMode(
          requested: bar.mode ?? LiquidGlassTheme.of(context).defaultMode,
          environment: GlassPlatform.instance.environment.value,
        ) ==
        EffectiveGlassMode.material;
