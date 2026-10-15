import 'package:flutter/widgets.dart';

import '../button/glass_button_role.dart';

/// A button of a [showGlassAlert] alert, a [showGlassConfirmationDialog]
/// or a `showGlassActionSheet`.
@immutable
class GlassDialogAction {
  /// Creates an action.
  const GlassDialogAction({
    required this.label,
    this.subtitle,
    this.onPressed,
    this.role = GlassButtonRole.none,
  });

  /// The button's label.
  final String label;

  /// A second line under [label], in iOS's secondary label colour (on the
  /// Material path, the theme's `onSurfaceVariant`). Read with the label.
  final String? subtitle;

  /// Called after the dialog closes. Null only closes it.
  final VoidCallback? onPressed;

  /// [GlassButtonRole.destructive] draws the label red;
  /// [GlassButtonRole.cancel] is the action a tap outside takes.
  final GlassButtonRole role;
}
