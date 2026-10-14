import 'package:flutter/widgets.dart';

import 'render_vibrant_blend.dart';
import 'tab_vibrancy_program.dart';
import 'vibrancy_kind.dart';

/// Paints [child] (tab glyphs, or the selected pill) vibrant, as iOS's tab
/// bar does: e.g. an untinted label pixel keeps the hue of the glass
/// behind it and takes the glyph's lightness (see [VibrancyKind]). [child] are rasterised and composited onto the
/// backdrop by `tab_vibrancy.frag`, so the glass must be Flutter's (shader
/// glass). Paints [child] normally when not [enabled], until the shader is
/// loaded, or when [child] needs compositing.
class VibrantBlend extends SingleChildRenderObjectWidget {
  /// Paints [child] vibrant when [enabled].
  const VibrantBlend({
    super.key,
    this.enabled = true,
    this.dark = false,
    this.kind = VibrancyKind.label,
    super.child,
  });

  /// What [child] is: a label, the selected tint or the selected pill
  /// (whose alpha is the pill's coverage).
  final VibrancyKind kind;

  /// Whether to blend; false paints the child normally.
  final bool enabled;

  /// Whether the glass is dark (iOS's dark vibrancy).
  final bool dark;

  @override
  RenderVibrantBlend createRenderObject(BuildContext context) {
    if (enabled) TabVibrancyProgram.instance.load();
    return RenderVibrantBlend(
      enabled: enabled,
      dark: dark,
      kind: kind,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderVibrantBlend renderObject,
  ) {
    if (enabled) TabVibrancyProgram.instance.load();
    renderObject
      ..enabled = enabled
      ..dark = dark
      ..kind = kind
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}
