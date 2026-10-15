import 'package:flutter/widgets.dart';

/// One item of a glass menu ([GlassMenuButton], `GlassPicker`,
/// `GlassContextMenu`).
@immutable
class GlassMenuItem {
  /// Creates an item.
  const GlassMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
    this.checked,
    this.semanticLabel,
    this.color,
  });

  /// The item's label.
  final String label;

  /// Called when the item is chosen, after the menu closes. Null disables
  /// the item.
  final VoidCallback? onSelected;

  /// An icon at the row's start, as iOS 26 draws it.
  final IconData? icon;

  /// Whether the action destroys data: drawn in red.
  final bool destructive;

  /// For a choice: whether it is the current one (a checkmark). Null for
  /// a plain action. A menu with any choice gives every row the
  /// checkmark column, as SwiftUI's picker menu does.
  final bool? checked;

  /// What assistive tech reads instead of [label].
  final String? semanticLabel;

  /// A tint for the label and icon (and checkmark) on both paths. Null
  /// keeps the default label colour. A disabled item stays dimmed and a
  /// [destructive] one stays red: both take precedence over [color].
  final Color? color;
}
