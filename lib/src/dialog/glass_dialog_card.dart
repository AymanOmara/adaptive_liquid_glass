import 'package:flutter/cupertino.dart';

import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/ios_text.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import 'dialog_metrics.dart';
import 'glass_dialog_action.dart';
import 'glass_dialog_button.dart';

/// The glass card of an alert or a confirmation dialog, laid out as
/// SwiftUI's.
///
/// An alert ([confirmation] false) has a leading semibold title, a
/// secondary message and, for two actions, the buttons side by side. A
/// confirmation dialog has a centred secondary title and its buttons
/// stacked.
class GlassDialogCard extends StatelessWidget {
  /// Creates the card.
  const GlassDialogCard({
    super.key,
    required this.actions,
    required this.onAction,
    required this.confirmation,
    this.title,
    this.message,
    this.mode,
  });

  /// The card's title.
  final String? title;

  /// The alert's message.
  final String? message;

  /// The buttons, in order.
  final List<GlassDialogAction> actions;

  /// Called with the tapped action.
  final ValueChanged<GlassDialogAction> onAction;

  /// A confirmation dialog rather than an alert.
  final bool confirmation;

  /// The rendering path.
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    Color resolve(Color c) => CupertinoDynamicColor.resolve(c, context);
    final secondary = resolve(CupertinoColors.secondaryLabel);
    final title = this.title;
    final message = this.message;
    final buttons = [
      for (final a in actions)
        GlassDialogButton(action: a, onTap: () => onAction(a)),
    ];
    final side = !confirmation && buttons.length == 2;
    final text = Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: confirmation ? 0 : DialogMetrics.textInset,
      ),
      child: Column(
        crossAxisAlignment: confirmation
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title,
              textAlign: confirmation ? TextAlign.center : TextAlign.start,
              style: IOSText.style(
                DialogMetrics.titleSize,
                weight: confirmation ? FontWeight.w400 : FontWeight.w600,
                color: confirmation
                    ? secondary
                    : resolve(CupertinoColors.label),
              ),
            ),
          if (title != null && message != null)
            const SizedBox(height: DialogMetrics.messageGap),
          if (message != null)
            Text(
              message,
              textAlign: confirmation ? TextAlign.center : TextAlign.start,
              style: IOSText.style(
                DialogMetrics.messageSize,
                color: secondary,
              ).copyWith(height: 22 / DialogMetrics.messageSize),
            ),
        ],
      ),
    );
    return SizedBox(
      width: confirmation
          ? DialogMetrics.dialogWidth
          : DialogMetrics.alertWidth,
      child: GlassGroup(
        mode: mode,
        child: LiquidGlass(
          mode: mode,
          shape: const GlassShape.rect(DialogMetrics.cornerRadius),
          adaptiveForeground: false,
          padding: const EdgeInsets.fromLTRB(
            DialogMetrics.padding,
            DialogMetrics.titleTop,
            DialogMetrics.padding,
            DialogMetrics.padding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null || message != null) ...[
                text,
                const SizedBox(height: DialogMetrics.buttonsGap),
              ],
              if (side)
                Row(
                  children: [
                    Expanded(child: buttons[0]),
                    const SizedBox(width: DialogMetrics.buttonSpacing),
                    Expanded(child: buttons[1]),
                  ],
                )
              else
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0)
                    const SizedBox(height: DialogMetrics.buttonSpacing),
                  buttons[i],
                ],
            ],
          ),
        ),
      ),
    );
  }
}
