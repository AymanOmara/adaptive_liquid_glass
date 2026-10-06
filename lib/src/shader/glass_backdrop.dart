import 'package:flutter/widgets.dart';

import '../group/glass_registry.dart';
import 'glass_backdrop_config.dart';
import 'render_glass_backdrop.dart';

/// Paints the group's glass behind its child.
class GlassBackdrop extends SingleChildRenderObjectWidget {
  /// Creates the backdrop.
  const GlassBackdrop({
    super.key,
    required this.registry,
    required this.config,
    this.backdropKey,
    super.child,
  });

  /// Members to draw.
  final GlassRegistry registry;

  /// Drawing parameters.
  final GlassBackdropConfig config;

  /// Shared backdrop capture key from an enclosing `BackdropGroup`.
  final BackdropKey? backdropKey;

  @override
  RenderGlassBackdrop createRenderObject(BuildContext context) =>
      RenderGlassBackdrop(
        registry: registry,
        config: config,
        backdropKey: backdropKey,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassBackdrop renderObject,
  ) {
    renderObject
      ..registry = registry
      ..config = config
      ..backdropKey = backdropKey;
  }
}
