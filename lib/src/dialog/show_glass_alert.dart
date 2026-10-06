import 'package:flutter/material.dart';

import '../button/glass_button_role.dart';
import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/theme.dart';
import '../platform/glass_platform.dart';
import 'glass_dialog_action.dart';
import 'glass_dialog_route.dart';

/// Shows an iOS 26 alert, like SwiftUI's `.alert`: a glass card in the
/// middle of the dimmed screen with a title, an optional message and its
/// [actions] as capsule buttons (two side by side, more stacked).
///
/// ```dart
/// showGlassAlert(
///   context: context,
///   title: 'Delete photo?',
///   message: 'This photo will be deleted from all your devices.',
///   actions: [
///     const GlassDialogAction(label: 'Cancel', role: GlassButtonRole.cancel),
///     GlassDialogAction(
///       label: 'Delete',
///       role: GlassButtonRole.destructive,
///       onPressed: delete,
///     ),
///   ],
/// );
/// ```
///
/// The alert closes when a button is tapped, then runs its `onPressed`;
/// the returned future completes with that action. On the Material path
/// it is a Material 3 [AlertDialog].
Future<GlassDialogAction?> showGlassAlert({
  required BuildContext context,
  required String title,
  String? message,
  required List<GlassDialogAction> actions,
  GlassRenderMode? mode,
}) async {
  assert(actions.isNotEmpty, 'An alert needs at least one action.');
  final effective = resolveGlassMode(
    requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
  );
  final GlassDialogAction? chosen;
  if (effective == EffectiveGlassMode.material) {
    chosen = await showDialog<GlassDialogAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          for (final a in actions)
            TextButton(
              onPressed: () => Navigator.of(context).pop(a),
              style: a.role == GlassButtonRole.destructive
                  ? TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              child: Text(a.label),
            ),
        ],
      ),
    );
  } else {
    chosen = await Navigator.of(context).push(
      GlassDialogRoute(
        title: title,
        message: message,
        actions: actions,
        confirmation: false,
        mode: mode,
        barrierLabel: cupertinoL10n(context).modalBarrierDismissLabel,
      ),
    );
  }
  chosen?.onPressed?.call();
  return chosen;
}
