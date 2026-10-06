import 'package:flutter/widgets.dart';

import '../core/glass_render_mode.dart';
import 'popover_metrics.dart';
import 'show_glass_popover.dart';

/// Opens a popover from whatever [builder] draws (it gets the callback
/// that opens it). While the popover is open it takes the opener's place,
/// as SwiftUI's does: the opener leaves the tree (native glass cannot be
/// hidden, and the bubble's glass would refract it).
class GlassPopoverAnchor extends StatefulWidget {
  /// Creates the anchor.
  const GlassPopoverAnchor({
    super.key,
    required this.builder,
    required this.popoverBuilder,
    this.overlap = PopoverMetrics.overlap,
    this.mode,
  });

  /// Draws the opener; call the given callback to open the popover.
  final Widget Function(BuildContext context, VoidCallback open) builder;

  /// Builds the popover's content.
  final WidgetBuilder popoverBuilder;

  /// See [showGlassPopover].
  final double overlap;

  /// The rendering path.
  final GlassRenderMode? mode;

  @override
  State<GlassPopoverAnchor> createState() => _GlassPopoverAnchorState();
}

class _GlassPopoverAnchorState extends State<GlassPopoverAnchor> {
  bool _open = false;
  Size _size = Size.zero;

  Future<void> _show() async {
    _size = (context.findRenderObject()! as RenderBox).size;
    final route = showGlassPopover<void>(
      context: context,
      builder: widget.popoverBuilder,
      overlap: widget.overlap,
      mode: widget.mode,
    );
    setState(() => _open = true);
    await route;
    if (mounted) setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) =>
      _open ? SizedBox.fromSize(size: _size) : widget.builder(context, _show);
}
