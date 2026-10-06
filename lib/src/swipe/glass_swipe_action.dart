import 'package:flutter/widgets.dart';

/// One action revealed by swiping a [GlassSwipeActions] row: a tinted
/// glass capsule with [icon], and [label] under it.
@immutable
class GlassSwipeAction {
  /// Creates an action.
  const GlassSwipeAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  /// The capsule's icon.
  final IconData icon;

  /// The label under the capsule, also the accessibility action's name.
  final String label;

  /// Called when the action is tapped or fully swiped; the row closes
  /// first.
  final VoidCallback onPressed;

  /// The capsule's tint. Defaults to system gray; use system red for a
  /// destructive action.
  final Color? color;
}
