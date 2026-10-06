import 'package:flutter/widgets.dart';

import 'degraded_look.dart';
import 'render_glass_loading_surface.dart';

/// Paints the degraded glass while the shader loads; see
/// [RenderGlassLoadingSurface].
class LoadingSurface extends SingleChildRenderObjectWidget {
  /// Creates the surface.
  const LoadingSurface({
    super.key,
    required this.enabled,
    required this.border,
    required this.look,
    required this.opaqueColor,
    required this.textDirection,
    super.child,
  });

  /// Whether the surface paints at all.
  final bool enabled;

  /// The glass outline.
  final OutlinedBorder border;

  /// The degraded material's colours.
  final DegradedLook look;

  /// A solid fill that replaces the look (Reduce Transparency), if any.
  final Color? opaqueColor;

  /// Resolves [border]'s directional parts.
  final TextDirection? textDirection;

  @override
  RenderGlassLoadingSurface createRenderObject(BuildContext context) =>
      RenderGlassLoadingSurface(
        enabled: enabled,
        border: border,
        look: look,
        opaqueColor: opaqueColor,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassLoadingSurface renderObject,
  ) {
    renderObject
      ..enabled = enabled
      ..border = border
      ..look = look
      ..opaqueColor = opaqueColor
      ..textDirection = textDirection;
  }
}
