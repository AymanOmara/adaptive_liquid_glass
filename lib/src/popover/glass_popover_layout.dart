import 'package:flutter/widgets.dart';

import 'popover_metrics.dart';

/// Places a popover bubble: centred on [anchor], its top
/// [PopoverMetrics.overlap] below the anchor's top (or, without room
/// below, its bottom that far above the anchor's bottom), kept
/// [PopoverMetrics.margin] inside the screen.
class GlassPopoverLayout extends SingleChildLayoutDelegate {
  /// Lays out a popover for [anchor] (global coordinates) inside
  /// [padding] (the screen's safe area).
  GlassPopoverLayout({required this.anchor, required this.padding});

  /// The anchor's rectangle.
  final Rect anchor;

  /// The screen's safe area.
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          constraints.maxWidth - PopoverMetrics.margin * 2,
          constraints.maxHeight - padding.vertical - PopoverMetrics.margin * 2,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final m = PopoverMetrics.margin;
    final x = (anchor.center.dx - childSize.width / 2).clamp(
      m,
      size.width - m - childSize.width,
    );
    final below = anchor.top + PopoverMetrics.overlap;
    final fitsBelow = below + childSize.height <= size.height - padding.bottom - m;
    final y = fitsBelow
        ? below
        : (anchor.bottom - PopoverMetrics.overlap - childSize.height).clamp(
            padding.top + m,
            size.height,
          );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(GlassPopoverLayout old) =>
      old.anchor != anchor || old.padding != padding;
}
