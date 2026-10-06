import 'package:flutter/cupertino.dart';

import '../button/glass_button_role.dart';
import '../core/glass_colors.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import 'dialog_metrics.dart';
import 'glass_dialog_action.dart';

/// A dialog button as SwiftUI draws it: a capsule of 12% black on the
/// glass, its label 17 pt (red for a destructive action).
class GlassDialogButton extends StatelessWidget {
  /// Creates the button for [action]; [onTap] closes the dialog and runs
  /// it.
  const GlassDialogButton({
    super.key,
    required this.action,
    required this.onTap,
    this.emphasised = false,
  });

  /// A confirmation dialog's heavier labels (semibold; destructive
  /// medium), as SwiftUI draws them.
  final bool emphasised;

  /// The action shown.
  final GlassDialogAction action;

  /// Called when the button is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final destructive = action.role == GlassButtonRole.destructive;
    final colour = CupertinoDynamicColor.resolve(
      destructive ? GlassSystemColors.red : CupertinoColors.label,
      context,
    );
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: DialogMetrics.buttonHeight,
          child: DecoratedBox(
            decoration: const ShapeDecoration(
              shape: StadiumBorder(),
              color: GlassColors.dialogButtonFill,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: IOSText.style(
                    DialogMetrics.buttonSize,
                    weight: switch ((emphasised, destructive)) {
                      (true, true) => FontWeight.w500,
                      (true, false) => FontWeight.w600,
                      (false, true) => FontWeight.w400,
                      (false, false) => FontWeight.w500,
                    },
                    color: colour,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
