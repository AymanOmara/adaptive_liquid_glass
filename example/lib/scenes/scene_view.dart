import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/widgets.dart';

import 'scene.dart';

/// Renders a [Scene] full screen: background stretched to the screen, glass
/// at absolute logical positions.
class SceneView extends StatelessWidget {
  /// Creates the view for [scene].
  const SceneView({super.key, required this.scene});

  /// The scene to render.
  final Scene scene;

  @override
  Widget build(BuildContext context) {
    // Scene coordinates are physical screen positions (left/top), shared
    // with the SwiftUI host, so `Positioned` is intentional here.
    final shapes = Stack(
      children: [
        for (final s in scene.shapes)
          Positioned.fromRect(
            rect: s.rect,
            child: LiquidGlass(
              glass: s.glass,
              shape: s.shape,
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(platformBrightness: scene.brightness),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/${scene.background}.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          Positioned.fill(
            child: scene.spacing == null
                ? shapes
                : GlassGroup(spacing: scene.spacing!, child: shapes),
          ),
        ],
      ),
    );
  }
}
