import 'package:flutter/material.dart';

import '../button/glass_button_role.dart';
import 'glass_dialog_action.dart';

/// A Material dialog button's label for [action]: its label, and its
/// subtitle under it in the theme's `onSurfaceVariant`.
Widget materialDialogActionLabel(
  BuildContext context,
  GlassDialogAction action,
) {
  final subtitle = action.subtitle;
  if (subtitle == null) return Text(action.label);
  final theme = Theme.of(context);
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(action.label),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

/// A Material dialog button's style for [action]: its tint, or the
/// theme's error colour for a destructive action; null otherwise.
ButtonStyle? materialDialogActionStyle(
  BuildContext context,
  GlassDialogAction action,
) {
  final colour =
      action.tint ??
      (action.role == GlassButtonRole.destructive
          ? Theme.of(context).colorScheme.error
          : null);
  return colour == null ? null : TextButton.styleFrom(foregroundColor: colour);
}
