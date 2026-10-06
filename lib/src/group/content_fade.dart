import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'render_content_fade.dart';

/// Fades member content during morphs. Fixed tree depth (no remount when a
/// fade ends), no rebuild per tick, and no layer outside a fade.
class ContentFade extends SingleChildRenderObjectWidget {
  /// Creates the fade.
  const ContentFade({super.key, required this.opacity, super.child});

  /// The content's opacity over the morph, from the member's entry.
  final ValueListenable<double> opacity;

  @override
  RenderContentFade createRenderObject(BuildContext context) =>
      RenderContentFade(opacity);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderContentFade renderObject,
  ) => renderObject.opacity = opacity;
}
