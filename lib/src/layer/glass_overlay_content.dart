import 'package:flutter/widgets.dart';

import 'glass_layer_anchor.dart';

/// Content laid over glass from outside the glass's group: a sibling in a
/// [Stack], a badge, a floating label.
///
/// On Android's shared glass layer a group's glass draws after the whole
/// route, so such content would otherwise draw beneath the glass. This
/// defers [child] into the layer, in paint order; elsewhere (iOS, or the
/// shared layer switched off) it paints in place, no visible difference.
/// It costs a repaint boundary.
///
/// ```dart
/// Stack(
///   children: [
///     LiquidGlass(child: const SizedBox(width: 80, height: 40)),
///     Positioned(
///       left: 20,
///       top: 10,
///       child: GlassOverlayContent(child: const Text('over the glass')),
///     ),
///   ],
/// )
/// ```
class GlassOverlayContent extends StatelessWidget {
  /// Creates overlay content.
  const GlassOverlayContent({super.key, required this.child});

  /// The content to keep above the glass.
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      GlassLayerContent(enabled: true, child: child);
}
