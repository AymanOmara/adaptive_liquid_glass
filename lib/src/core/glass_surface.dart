import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;

import '../degraded/degraded_look.dart';
import '../material/material_glass.dart';
import 'effective_glass_mode.dart';
import 'glass.dart';
import 'glass_brightness.dart';
import 'glass_mode_builder.dart';
import 'glass_render_mode.dart';
import 'glass_variant.dart';
import 'liquid_glass_theme.dart';

/// The colour a glass surface resolves to, for contrast checks on what is
/// drawn over it.
///
/// ```dart
/// final surface = GlassSurface.colorOf(context, glass: Glass.regular);
/// final ok = contrastRatio(labelColor, surface) >= 4.5;
/// ```
abstract final class GlassSurface {
  /// The opaque colour of [glass] (the theme's default when null) over
  /// [backdrop] at [context], on the path [mode] resolves to.
  ///
  /// On the Material path it is exact: the surface `LiquidGlass` paints
  /// (see [Glass.materialSurface]) over [backdrop]. On the glass paths it
  /// is an estimate: real glass samples and refracts whatever is behind it,
  /// so this is the glass's fill and tint composited over [backdrop], the
  /// page colour by default (the Cupertino theme's scaffold background).
  /// Pass the colour actually behind the glass for a closer estimate.
  static Color colorOf(
    BuildContext context, {
    Glass? glass,
    Color? backdrop,
    GlassRenderMode? mode,
  }) {
    final theme = LiquidGlassTheme.of(context);
    final g = glass ?? theme.defaultGlass;
    final effective = resolveGlassModeOf(context, mode: mode);
    if (effective == EffectiveGlassMode.material) {
      final scheme = Theme.of(context).colorScheme;
      final behind = backdrop ?? scheme.surface;
      if (g.variant == GlassVariant.identity) return behind;
      return Color.alphaBlend(materialGlassColor(g, scheme), behind);
    }
    final behind = CupertinoDynamicColor.resolve(
      backdrop ?? CupertinoTheme.of(context).scaffoldBackgroundColor,
      context,
    );
    if (g.variant == GlassVariant.identity) return behind;
    final brightness =
        glassBrightnessOf(context) ?? MediaQuery.platformBrightnessOf(context);
    final look = DegradedLook.of(g, theme.constants, brightness);
    return Color.alphaBlend(look.fill, behind);
  }
}
