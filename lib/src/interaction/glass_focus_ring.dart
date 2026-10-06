import 'package:flutter/cupertino.dart';

import '../core/glass_colors.dart';
import '../core/glass_shape.dart';
import '../core/shape_border.dart';
import 'focus_ring_metrics.dart';

/// Draws a focus ring around [child] in [shape] while the nearest
/// enclosing `Focus` has primary focus and focus is being driven by a
/// keyboard ([FocusHighlightMode.traditional]). Touch focus draws nothing.
///
/// Place it below the `Focus` it reports on. Internal.
class GlassFocusRing extends StatefulWidget {
  /// Creates a focus ring.
  const GlassFocusRing({
    super.key,
    this.shape = const GlassShape.capsule(),
    required this.child,
  });

  /// The outline the ring follows, outset by [FocusRingMetrics.gap].
  final GlassShape shape;

  /// The focused content.
  final Widget child;

  @override
  State<GlassFocusRing> createState() => _GlassFocusRingState();
}

class _GlassFocusRingState extends State<GlassFocusRing> {
  bool _keyboard =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onMode);
    super.dispose();
  }

  void _onMode(FocusHighlightMode mode) {
    final keyboard = mode == FocusHighlightMode.traditional;
    if (keyboard != _keyboard) setState(() => _keyboard = keyboard);
  }

  @override
  Widget build(BuildContext context) {
    final focused = Focus.maybeOf(context)?.hasPrimaryFocus ?? false;
    final show = focused && _keyboard;
    // Always built, so focus changes keep the child mounted; without a
    // painter it adds no layer.
    return CustomPaint(
      foregroundPainter: show
          ? _FocusRingPainter(
              border: _ringBorder(widget.shape),
              color: CupertinoDynamicColor.resolve(
                GlassColors.focusRing,
                context,
              ),
            )
          : null,
      child: widget.child,
    );
  }
}

/// Distance from the box's edge to the middle of the ring's stroke.
const double _outset = FocusRingMetrics.gap + FocusRingMetrics.width / 2;

/// [shape]'s outline for the outset ring: rect corners grow by the outset
/// so the ring stays concentric with the glass.
OutlinedBorder _ringBorder(GlassShape shape) => switch (shape) {
  RectGlassShape(:final cornerRadius) => RoundedSuperellipseBorder(
    borderRadius: BorderRadius.circular(cornerRadius + _outset),
  ),
  _ => sizeIndependentBorder(shape),
};

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({required this.border, required this.color});

  final OutlinedBorder border;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(_outset);
    canvas.drawPath(
      border.getOuterPath(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = FocusRingMetrics.width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.border != border || old.color != color;
}
