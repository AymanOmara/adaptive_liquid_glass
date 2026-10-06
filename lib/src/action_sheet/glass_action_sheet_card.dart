import 'package:flutter/cupertino.dart';

import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/ios_text.dart';
import '../dialog/dialog_metrics.dart';
import '../dialog/glass_dialog_action.dart';
import '../dialog/glass_dialog_button.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import 'action_sheet_metrics.dart';

/// Internal. The glass card of [showGlassActionSheet], laid out as
/// UIKit's action sheet: a centred secondary title and message, the
/// actions stacked as capsule buttons, and the cancel button set apart.
class GlassActionSheetCard extends StatelessWidget {
  /// Creates the card.
  const GlassActionSheetCard({
    super.key,
    required this.actions,
    required this.onAction,
    this.title,
    this.message,
    this.cancel,
    this.mode,
  });

  /// The card's title.
  final String? title;

  /// The card's message.
  final String? message;

  /// The buttons, in order.
  final List<GlassDialogAction> actions;

  /// The cancel button, set apart below the actions.
  final GlassDialogAction? cancel;

  /// Called with the tapped action.
  final ValueChanged<GlassDialogAction> onAction;

  /// The rendering path.
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );
    final title = this.title;
    final message = this.message;
    final hasText = title != null || message != null;
    final cancel = this.cancel;
    return SizedBox(
      width: double.infinity,
      child: GlassGroup(
        mode: mode,
        child: LiquidGlass(
          mode: mode,
          shape: const GlassShape.rect(ActionSheetMetrics.cornerRadius),
          adaptiveForeground: false,
          padding: EdgeInsetsDirectional.fromSTEB(
            ActionSheetMetrics.padding,
            hasText ? ActionSheetMetrics.titleTop : ActionSheetMetrics.padding,
            ActionSheetMetrics.padding,
            ActionSheetMetrics.padding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasText) ...[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null)
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: IOSText.style(
                          ActionSheetMetrics.titleSize,
                          weight: FontWeight.w600,
                          color: secondary,
                        ),
                      ),
                    if (title != null && message != null)
                      const SizedBox(height: ActionSheetMetrics.textGap),
                    if (message != null)
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: IOSText.style(
                          ActionSheetMetrics.messageSize,
                          color: secondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: ActionSheetMetrics.buttonsGap),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0)
                          const SizedBox(height: DialogMetrics.buttonSpacing),
                        GlassDialogButton(
                          action: actions[i],
                          onTap: () => onAction(actions[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (cancel != null) ...[
                if (actions.isNotEmpty)
                  const SizedBox(
                    height:
                        DialogMetrics.buttonSpacing +
                        ActionSheetMetrics.cancelGap,
                  ),
                GlassDialogButton(
                  action: cancel,
                  emphasised: true,
                  onTap: () => onAction(cancel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
