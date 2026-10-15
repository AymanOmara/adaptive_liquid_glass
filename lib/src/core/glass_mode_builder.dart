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
          resolveGlassModeOf(context, mode: mode, environment: environment),
        ),
      );
}

/// The rendering path [mode] resolves to at [context] (the theme's default
/// when null) in [environment] (the platform's current one when null): the
/// theme's Android flag, high contrast, Reduce Transparency, the platform
/// and the iOS version, as every glass widget resolves it.
EffectiveGlassMode resolveGlassModeOf(
  BuildContext context, {
  GlassRenderMode? mode,
  GlassEnvironment? environment,
}) {
  final theme = LiquidGlassTheme.of(context);
  return resolveGlassMode(
    requested: mode ?? theme.defaultMode,
    environment: environment ?? GlassPlatform.instance.environment.value,
    highContrast: MediaQuery.highContrastOf(context),
    supportLiquidGlassOnAndroid: theme.supportLiquidGlassOnAndroid,
  );
}
