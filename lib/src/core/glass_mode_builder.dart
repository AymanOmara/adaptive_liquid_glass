import 'package:flutter/widgets.dart';

import '../platform/glass_platform.dart';
import 'effective_glass_mode.dart';
import 'glass_environment.dart';
import 'glass_render_mode.dart';
import 'liquid_glass_theme.dart';
import 'render_mode_resolver.dart';

/// Builds with the rendering path [mode] resolves to here (the theme's
/// default when null), rebuilding when the platform environment changes.
class GlassModeBuilder extends StatelessWidget {
  /// Creates the builder.
  const GlassModeBuilder({super.key, this.mode, required this.builder});

  /// The requested mode; null takes the theme's default.
  final GlassRenderMode? mode;

  /// Builds for the resolved path.
  final Widget Function(BuildContext context, EffectiveGlassMode mode) builder;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<GlassEnvironment>(
        valueListenable: GlassPlatform.instance.environment,
        builder: (context, environment, _) => builder(
          context,
          resolveGlassMode(
            requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
            environment: environment,
          ),
        ),
      );
}
