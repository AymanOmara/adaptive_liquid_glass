import 'package:flutter/cupertino.dart';

import '../button/glass_button_role.dart';
import '../core/glass_colors.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import 'dialog_metrics.dart';
import 'glass_dialog_action.dart';

/// A dialog button as SwiftUI draws it: a capsule of 12% black on the
/// glass, its label 17 pt (red for a destructive action), and an
/// action's subtitle under it in the secondary label colour.
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
      destructive ? GlassSystemColors.red : GlassColors.label,
      context,
    );
    // At larger Dynamic Type the button grows and its label wraps.
    final wraps =
        MediaQuery.textScalerOf(context).scale(DialogMetrics.buttonSize) >
        DialogMetrics.buttonSize;
    final subtitle = action.subtitle;
    // A subtitle grows the button like a wrapped label.
    final grows = wraps || subtitle != null;
    final label = Text(
      action.label,
      maxLines: wraps ? null : 1,
      overflow: wraps ? null : TextOverflow.ellipsis,
      textAlign: TextAlign.center,
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
    );
    // Its own node: the label and subtitle are read together, apart from
    // the card's title.
    return Semantics(
      container: true,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: grows
              ? const BoxConstraints(minHeight: DialogMetrics.buttonHeight)
              : const BoxConstraints.tightFor(
                  height: DialogMetrics.buttonHeight,
                ),
          child: DecoratedBox(
            decoration: const ShapeDecoration(
              shape: StadiumBorder(),
              color: GlassColors.dialogButtonFill,
            ),
            child: Center(
              heightFactor: grows ? 1 : null,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: wraps
                      ? DialogMetrics.wrappedButtonPadding
                      : subtitle != null
                      ? DialogMetrics.subtitleButtonPadding
                      : 0,
                ),
                child: subtitle == null
                    ? label
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          label,
                          Text(
                            subtitle,
                            maxLines: wraps ? null : 1,
                            overflow: wraps ? null : TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: IOSText.style(
                              DialogMetrics.subtitleSize,
                              color: CupertinoDynamicColor.resolve(
                                GlassColors.secondaryLabel,
                                context,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
