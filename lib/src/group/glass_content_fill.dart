import 'package:flutter/widgets.dart';

import 'concentric_scope.dart';
import 'glass_fill_style.dart';
import 'glass_group_scope.dart';
import 'render_glass_content_fill.dart';

/// A system fill drawn by native glass inside the enclosing `LiquidGlass`,
/// as SwiftUI content of its `.glassEffect` view: SwiftUI gives such fills
/// the glass's vibrancy (iOS 26's tab bar draws its selected pill this
/// way), which Flutter, unable to see UIKit glass, cannot. Paints nothing
/// itself; only the native path draws it.
class GlassContentFill extends SingleChildRenderObjectWidget {
  /// Fills this box with [style] at [opacity], as a capsule.
  const GlassContentFill({
    super.key,
    this.style = GlassFillStyle.tertiary,
    this.opacity = 1,
    super.child,
  });

  /// The system fill.
  final GlassFillStyle style;

  /// The fill's opacity.
  final double opacity;

  @override
  RenderGlassContentFill createRenderObject(BuildContext context) =>
      RenderGlassContentFill(
        entry: ConcentricScope.maybeOf(context),
        registry: GlassGroupScope.maybeOf(context)?.registry,
        style: style,
        opacity: opacity,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassContentFill renderObject,
  ) {
    renderObject
      ..entry = ConcentricScope.maybeOf(context)
      ..registry = GlassGroupScope.maybeOf(context)?.registry
      ..style = style
      ..opacity = opacity;
  }
}
