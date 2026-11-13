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
      constraints.loosen().copyWith(
        maxWidth: (constraints.maxWidth - 2 * ContextMenuMetrics.margin).clamp(
          0.0,
          double.infinity,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const m = ContextMenuMetrics.margin;
    final maxX = size.width - m - childSize.width;
    final x = maxX < m
        ? (size.width - childSize.width) / 2
        : (preview.center.dx - childSize.width / 2).clamp(m, maxX);
    // The menu keeps the lifted item's distance from the safe area's top
    // and bottom.
    const v = ContextMenuMetrics.safeMargin;
    final minY = (padding.top + v).clamp(0.0, size.height);
    final maxY = size.height - padding.bottom - v - childSize.height;
    final below = preview.bottom + ContextMenuMetrics.gap;
    final above = preview.top - ContextMenuMetrics.gap - childSize.height;
    final y = below <= maxY
        ? below
        : above >= minY
        ? above
        : maxY.clamp(minY, size.height);
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(GlassContextMenuLayout old) =>
      old.preview != preview || old.padding != padding;
}
