import 'package:flutter/material.dart';

import '../button/glass_button_role.dart';
import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/theme.dart';
import '../dialog/glass_dialog_action.dart';
import '../platform/glass_platform.dart';
import 'glass_action_sheet_route.dart';

/// Shows an iOS 26 action sheet, like UIKit's `UIAlertController` with
/// `.actionSheet` on iPhone: a glass card floating at the bottom of the
/// screen with an optional centred [title] and [message], the [actions]
/// stacked as capsule buttons, and the [cancel] button set apart below.
///
/// ```dart
/// showGlassActionSheet(
///   context: context,
///   title: 'Photo',
///   message: 'What would you like to do with it?',
///   actions: [
///     GlassDialogAction(label: 'Share', onPressed: share),
///     GlassDialogAction(
///       label: 'Delete',
///       role: GlassButtonRole.destructive,
///       onPressed: delete,
///     ),
///   ],
///   cancel: const GlassDialogAction(
///     label: 'Cancel',
///     role: GlassButtonRole.cancel,
///   ),
/// );
/// ```
///
/// The sheet closes when a button is tapped, then runs its `onPressed`.
/// A tap outside takes [cancel]; when [cancel] is null a tap outside just
/// closes the sheet and the future completes with null. The future
/// completes with the chosen action. On the Material path it is a
/// Material 3 modal bottom sheet with a list.
Future<GlassDialogAction?> showGlassActionSheet({
  required BuildContext context,
  String? title,
  String? message,
  required List<GlassDialogAction> actions,
  GlassDialogAction? cancel,
  GlassRenderMode? mode,
}) async {
  assert(
    actions.isNotEmpty || cancel != null,
    'An action sheet needs an action or a cancel button.',
  );
  final effective = resolveGlassMode(
    requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
  );
  GlassDialogAction? chosen;
  if (effective == EffectiveGlassMode.material) {
    chosen = await showModalBottomSheet<GlassDialogAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null || message != null)
              ListTile(
                title: title == null
                    ? null
                    : Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                subtitle: message == null ? null : Text(message),
              ),
            for (final a in actions)
              ListTile(
                title: Text(
                  a.label,
                  style: a.role == GlassButtonRole.destructive
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
                onTap: () => Navigator.of(context).pop(a),
              ),
            if (cancel != null) ...[
              const Divider(),
              ListTile(
                title: Text(cancel.label),
                onTap: () => Navigator.of(context).pop(cancel),
              ),
            ],
          ],
        ),
      ),
    );
  } else {
    final navigator = Navigator.of(context);
    chosen = await navigator.push(
      GlassActionSheetRoute(
        title: title,
        message: message,
        actions: actions,
        cancel: cancel,
        mode: mode,
        capturedThemes: InheritedTheme.capture(
          from: context,
          to: navigator.context,
        ),
        barrierLabel: cupertinoL10n(context).modalBarrierDismissLabel,
      ),
    );
  }
  chosen ??= cancel;
  chosen?.onPressed?.call();
  return chosen;
}
