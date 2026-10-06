import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import 'control_metrics.dart';

/// A control's thumb: a solid capsule at rest that turns into a clear
/// glass lens, grown past its track, while [pressed] (0 at rest, 1 held;
/// it may spring past both).
class GlassThumb extends StatelessWidget {
  /// Creates a thumb.
  const GlassThumb({
    super.key,
    required this.pressed,
    required this.color,
    this.mode,
    this.child,
    this.shadow = false,
  });

  /// How far the thumb has turned into a lens.
  final double pressed;

  /// The solid capsule's colour at rest.
  final Color color;

  /// The lens's rendering path.
  final GlassRenderMode? mode;

  /// Drawn on the thumb (a segment's label).
  final Widget? child;

  /// Whether the resting thumb casts a soft shadow. SwiftUI's slider thumb
  /// does; its toggle and segmented thumbs are flat.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final t = pressed.clamp(0.0, 1.0);
    final scaleX = 1 + (ControlMetrics.lensScaleX - 1) * pressed;
    final scaleY = 1 + (ControlMetrics.lensScaleY - 1) * pressed;
    return Transform.scale(
      scaleX: scaleX < 0.8 ? 0.8 : scaleX,
      scaleY: scaleY < 0.8 ? 0.8 : scaleY,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (t < 1)
            Opacity(
              opacity: 1 - t,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: color,
                  shadows: shadow
                      ? const [
                          BoxShadow(
                            color: GlassColors.thumbShadow,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          // Only a visibly pressed thumb is glass: a hair-thin lens would
          // still refract its surroundings.
          // Its own group, so a control on a glass card does not blend
          // its lens into the card.
          if (t > 0.05)
            GlassGroup(
              mode: mode,
              child: LiquidGlass(
                glass: Glass.clear,
                mode: mode,
                adaptiveForeground: false,
                child: const SizedBox.expand(),
              ),
            ),
          if (child != null) Center(child: child),
        ],
      ),
    );
  }
}
