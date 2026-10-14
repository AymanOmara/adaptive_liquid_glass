import 'package:flutter/widgets.dart';

import 'context_menu_metrics.dart';

/// Places a context menu by its lifted item ([preview], global
/// coordinates, as [ContextMenuMetrics.lifted] places it): below it
/// (above without room), centred on it and kept [ContextMenuMetrics.margin]
/// from the screen's sides, as UIKit's (measured).
class GlassContextMenuLayout extends SingleChildLayoutDelegate {
  /// Lays out the menu for [preview] inside [padding].
  GlassContextMenuLayout({required this.preview, required this.padding});

  /// The lifted item's rectangle.
  final Rect preview;

  /// The screen's safe area.
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const m = ContextMenuMetrics.margin;
    final x = (preview.center.dx - childSize.width / 2).clamp(
      m,
      size.width - m - childSize.width,
    );
    final below = preview.bottom + ContextMenuMetrics.gap;
    final fits = below + childSize.height <= size.height - padding.bottom - m;
    final y = fits
        ? below
        : (preview.top - ContextMenuMetrics.gap - childSize.height).clamp(
            padding.top + m,
            size.height,
          );
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(GlassContextMenuLayout old) =>
      old.preview != preview || old.padding != padding;
}
