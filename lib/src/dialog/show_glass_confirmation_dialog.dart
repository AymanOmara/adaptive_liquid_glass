import 'package:flutter/material.dart';

import '../button/glass_button_role.dart';
import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/liquid_glass_theme.dart';
import '../core/render_mode_resolver.dart';
import '../platform/glass_platform.dart';
import 'glass_dialog_action.dart';
import 'glass_dialog_route.dart';

/// Shows an iOS 26 confirmation dialog, like SwiftUI's
/// `.confirmationDialog`: a small glass card in the middle of the screen
/// with a secondary title and its [actions] stacked.
///
/// As on iOS 26, a [GlassButtonRole.cancel] action is not drawn: a tap
/// outside the card takes it. The returned future completes with the
/// chosen action (the cancel action on a tap outside), after its
/// `onPressed` has run. On the Material path it is a Material 3
/// [AlertDialog] with the actions stacked.
Future<GlassDialogAction?> showGlassConfirmationDialog({
  required BuildContext context,
  String? title,
  required List<GlassDialogAction> actions,
  GlassRenderMode? mode,
}) async {
  final effective = resolveGlassMode(
    requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
    environment: GlassPlatform.instance.environment.value,
  );
  GlassDialogAction? cancel;
  for (final a in actions) {
    if (a.role == GlassButtonRole.cancel) cancel = a;
  }
  GlassDialogAction? chosen;
  if (effective == EffectiveGlassMode.material) {
    chosen = await showDialog<GlassDialogAction>(
      context: context,
      builder: (context) => AlertDialog(
        title: title == null ? null : Text(title),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: 8,
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
    final navigator = Navigator.of(context);
    chosen = await navigator.push(
      GlassDialogRoute(
        title: title,
        actions: [
          for (final a in actions)
            if (a.role != GlassButtonRole.cancel) a,
        ],
        confirmation: true,
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
