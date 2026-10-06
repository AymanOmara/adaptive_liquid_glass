import 'package:flutter/widgets.dart';

import '../button/glass_button_role.dart';

/// A button of a [showGlassAlert] alert or [showGlassConfirmationDialog].
@immutable
class GlassDialogAction {
  /// Creates an action.
  const GlassDialogAction({
    required this.label,
    this.onPressed,
    this.role = GlassButtonRole.none,
  });

  /// The button's label.
  final String label;

  /// Called after the dialog closes. Null only closes it.
  final VoidCallback? onPressed;

  /// [GlassButtonRole.destructive] draws the label red;
  /// [GlassButtonRole.cancel] is the action a tap outside takes.
  final GlassButtonRole role;
}
