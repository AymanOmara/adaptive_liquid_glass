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
    this.confirm,
    this.destructive = false,
  });

  /// The capsule's icon.
  final IconData icon;

  /// The label under the capsule, also the accessibility action's name.
  final String label;

  /// Called when the action is tapped or fully swiped; the row closes
  /// first.
  final VoidCallback onPressed;

  /// Asked before [onPressed] runs, from a tap or a full swipe (an alert,
  /// say). False keeps the item: the row closes and [onPressed] does not
  /// run. Null runs [onPressed] straight away.
  final Future<bool> Function()? confirm;

  /// The capsule's tint. Defaults to system red for a [destructive]
  /// action, system gray otherwise.
  final Color? color;

  /// Whether the action deletes the row's item, like SwiftUI's
  /// `role: .destructive`: a full swipe then slides the row away and
  /// collapses it before [onPressed] runs, which should remove the item.
  final bool destructive;
}
