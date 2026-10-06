import 'package:flutter/widgets.dart';

/// One action in a [GlassMenuButton]'s menu.
@immutable
class GlassMenuItem {
  /// Creates an item.
  const GlassMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
  });

  /// The item's label.
  final String label;

  /// Called when the item is chosen, after the menu closes. Null disables
  /// the item.
  final VoidCallback? onSelected;

  /// An icon at the row's end, as on iOS.
  final IconData? icon;

  /// Whether the action destroys data: drawn in red.
  final bool destructive;
}
