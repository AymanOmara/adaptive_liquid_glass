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
      // The glass appears with the decoded background, as in the SwiftUI
      // host, where the image is there from the first frame. Apple's glass
      // takes its light or dark look from what is behind it when it first
      // draws, and in mid-tone scenes keeps it, so native glass must not
      // first draw over the empty frames before the image decodes.
      child: Image.asset(
        'assets/backgrounds/${scene.background}.png',
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        frameBuilder: (context, image, frame, sync) => Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (frame != null || sync)
              scene.spacing == null
                  ? shapes
                  : GlassGroup(spacing: scene.spacing!, child: shapes),
          ],
        ),
      ),
    );
  }
}
