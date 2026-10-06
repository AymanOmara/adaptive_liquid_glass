import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';
import '../core/glass_shape.dart';
import '../core/glass_variant.dart';
import '../core/shape_border.dart';
import '../group/glass_group_scope.dart';
import 'degraded_look.dart';
import 'loading_surface.dart';

/// Shader-less glass shown while the shader program loads.
///
/// It paints what `DegradedGlass` paints (blur, fill and rim, or the opaque
/// fill under Reduce Transparency), but as one render object, so turning it
/// off or switching to the opaque fill keeps the child mounted. Disabled,
/// it paints only the child and adds no layer and no compositing.
class GlassLoadingSurface extends StatelessWidget {
  /// Creates the surface.
  const GlassLoadingSurface({
    super.key,
    required this.enabled,
    required this.glass,
    required this.shape,
    required this.constants,
    this.opaqueColor,
    required this.child,
  });

  /// Whether to draw; false once the shader has loaded.
  final bool enabled;

  /// Glass description.
  final Glass glass;

  /// Shape.
  final GlassShape shape;

  /// Rendering constants.
  final GlassConstants constants;

  /// Non-null when Reduce Transparency forces a solid surface.
  final Color? opaqueColor;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) => LoadingSurface(
    enabled: enabled && glass.variant != GlassVariant.identity,
    border: sizeIndependentBorder(shape),
    look: DegradedLook.of(
      glass,
      constants,
      // The group's resolved brightness; outside a group, the ambient
      // MediaQuery. See GlassGroupScope.brightnessOf.
      GlassGroupScope.brightnessOf(context),
    ),
    opaqueColor: opaqueColor,
    textDirection: Directionality.maybeOf(context),
    child: child,
  );
}
