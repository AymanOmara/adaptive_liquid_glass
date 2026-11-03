import 'package:flutter/widgets.dart';

import 'concentric_scope.dart';
import 'glass_group_scope.dart';
import 'render_glass_content_glyphs.dart';

/// Glyphs drawn by native glass inside the enclosing `LiquidGlass`, as
/// SwiftUI content of its `.glassEffect` view: [child] is rasterised to a
/// coverage mask and SwiftUI fills that mask with [color] moved towards
/// the glass beneath it, `color + gain × (glass − reference)` per channel,
/// as iOS 26's tab bar draws its selected tab. Flutter, unable to see
/// UIKit glass, cannot compose them itself.
///
/// The child keeps its layout, semantics and hit testing; once native
/// glass has the mask, Flutter stops painting it. Disabled, or outside
/// native glass, it paints the child as is.
class GlassContentGlyphs extends SingleChildRenderObjectWidget {
  /// Draws [child]'s coverage in [color], following the glass by [gain]
  /// around [reference], when [enabled].
  const GlassContentGlyphs({
    super.key,
    required this.enabled,
    required this.color,
    this.gain = 0,
    this.reference = 0,
    this.vibrant = false,
    super.child,
  });

  /// Whether native glass draws the glyphs.
  final bool enabled;

  /// The glyphs' colour over glass of [reference].
  final Color color;

  /// How much of the glass's difference from [reference] the glyphs take,
  /// from 0 (flat [color]) to 1.
  final double gain;

  /// The glass level (0–1, every channel) at which the glyphs are [color].
  final double reference;

  /// Whether the glyphs are vibrant instead, as iOS 26 draws untinted tab
  /// labels: [color]'s level with [gain] of the glass's chroma, taken at
  /// luminosity [reference] (a low one loses chroma).
  final bool vibrant;

  @override
  RenderGlassContentGlyphs createRenderObject(BuildContext context) =>
      RenderGlassContentGlyphs(
        entry: ConcentricScope.maybeOf(context),
        registry: GlassGroupScope.maybeOf(context)?.registry,
        enabled: enabled,
        color: color,
        gain: gain,
        reference: reference,
        vibrant: vibrant,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassContentGlyphs renderObject,
  ) {
    renderObject
      ..entry = ConcentricScope.maybeOf(context)
      ..registry = GlassGroupScope.maybeOf(context)?.registry
      ..enabled = enabled
      ..color = color
      ..gain = gain
      ..reference = reference
      ..vibrant = vibrant
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}
