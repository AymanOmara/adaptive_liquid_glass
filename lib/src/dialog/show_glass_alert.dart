import 'package:flutter/material.dart';

import '../button/glass_button_role.dart';
import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/liquid_glass_theme.dart';
import '../core/render_mode_resolver.dart';
import '../platform/glass_platform.dart';
import 'glass_alert_action_order.dart';
import 'glass_dialog_action.dart';
import 'glass_dialog_route.dart';
import 'material_dialog_action_label.dart';

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
///
/// [icon] sits above the title and [content] under the message (or in
/// its place), across the buttons' width: a text field, a picker. An
/// action's `subtitle` is a second line under its label.
///
/// [barrierDismissible] lets a tap outside close the alert, completing
/// with null; null keeps each path's default (iOS's alert stays, as on
/// iOS; Material's [AlertDialog] closes). [actionOrder] keeps the
/// [actions] as given (the default) or puts the cancel action where the
/// platform does; see [GlassAlertActionOrder].
Future<GlassDialogAction?> showGlassAlert({
  required BuildContext context,
  required String title,
  String? message,
  Widget? content,
  Widget? icon,
  required List<GlassDialogAction> actions,
  bool? barrierDismissible,
  GlassAlertActionOrder actionOrder = GlassAlertActionOrder.given,
  GlassRenderMode? mode,
}) async {
  assert(actions.isNotEmpty, 'An alert needs at least one action.');
  final effective = resolveGlassMode(
    requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
    highContrast: MediaQuery.highContrastOf(context),
  );
  final GlassDialogAction? chosen;
  if (effective == EffectiveGlassMode.material) {
    final ordered = actionOrder == GlassAlertActionOrder.platform
        ? [
            for (final a in actions)
              if (a.role == GlassButtonRole.cancel) a,
            for (final a in actions)
              if (a.role != GlassButtonRole.cancel) a,
          ]
        : actions;
    chosen = await showDialog<GlassDialogAction>(
      context: context,
      barrierDismissible: barrierDismissible ?? true,
      builder: (context) => AlertDialog(
        // Larger text scrolls rather than overflowing the screen.
        scrollable: MediaQuery.textScalerOf(context).scale(1) > 1,
        icon: icon,
        title: Text(title),
        content: message != null && content != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Text(message), const SizedBox(height: 16), content],
              )
            : content ?? (message == null ? null : Text(message)),
        actions: [
          for (final a in ordered)
            TextButton(
              onPressed: () => Navigator.of(context).pop(a),
              style: a.role == GlassButtonRole.destructive
                  ? TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    )
                  : null,
              child: materialDialogActionLabel(context, a),
            ),
        ],
      ),
    );
  } else {
    final navigator = Navigator.of(context);
    chosen = await navigator.push(
      GlassDialogRoute(
        title: title,
        message: message,
        icon: icon,
        content: content,
        actions: actions,
        platformOrder: actionOrder == GlassAlertActionOrder.platform,
        dismissible: barrierDismissible,
        confirmation: false,
        mode: mode,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        barrierLabel: cupertinoL10n(context).modalBarrierDismissLabel,
      ),
    );
  }
  chosen?.onPressed?.call();
  return chosen;
}
