import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show FilledButton, IconButton, Icons, TextButton, Theme;

import '../core/glass_colors.dart';
import '../core/ios_text.dart';
import 'glass_tip.dart';
import 'tip_metrics.dart';

/// A tip's content: image, title, message, close button and actions. The
/// platter around it is the caller's ([GlassTipView]'s card or the popover
/// bubble).
class TipBody extends StatelessWidget {
  /// Creates the content.
  const TipBody({
    super.key,
    required this.tip,
    required this.onClose,
    required this.closeLabel,
    required this.material,
  });

  /// What the tip says.
  final GlassTip tip;

  /// The close button's tap.
  final VoidCallback onClose;

  /// The close button's accessibility label.
  final String closeLabel;

  /// Whether to draw Material 3 content instead of iOS's.
  final bool material;

  @override
  Widget build(BuildContext context) =>
      material ? _material(context) : _ios(context);

  Widget _ios(BuildContext context) {
    final inherited = DefaultTextStyle.of(context).style;
    final tint = CupertinoDynamicColor.resolve(GlassColors.systemBlue, context);
    TextStyle text(double size, FontWeight weight, Color color) =>
        IOSText.inFontOf(
          IOSText.style(size, weight: weight, color: color),
          inherited,
        ).copyWith(height: TipMetrics.lineHeight / size);
    final secondary = CupertinoDynamicColor.resolve(
      GlassColors.secondaryLabel,
      context,
    );
    final fill = CupertinoDynamicColor.resolve(TipMetrics.fill, context);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tip.image != null) ...[
          SizedBox(
            width: TipMetrics.imageSlotWidth,
            child: IconTheme.merge(
              data: IconThemeData(color: tint, size: TipMetrics.imageSize),
              child: tip.image!,
            ),
          ),
          const SizedBox(width: TipMetrics.imageGap),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle(
                style: text(
                  TipMetrics.titleSize,
                  TipMetrics.titleWeight,
                  CupertinoDynamicColor.resolve(GlassColors.label, context),
                ),
                child: tip.title,
              ),
              if (tip.message != null) ...[
                const SizedBox(height: TipMetrics.messageGap),
                DefaultTextStyle(
                  style: text(
                    TipMetrics.messageSize,
                    FontWeight.w400,
                    secondary,
                  ),
                  child: tip.message!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return Stack(
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            top: TipMetrics.topInset,
            bottom: tip.actions.isEmpty ? TipMetrics.textBottomInset : 0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: TipMetrics.startInset,
                  end: TipMetrics.textEndInset,
                ),
                child: content,
              ),
              if (tip.actions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TipMetrics.actionInset,
                    TipMetrics.textBottomInset,
                    TipMetrics.actionInset,
                    TipMetrics.actionInset,
                  ),
                  child: _actionRow(
                    (action, prominent) => _IOSAction(
                      action: action,
                      fill: prominent ? tint : fill,
                      labelStyle: text(
                        TipMetrics.actionLabelSize,
                        FontWeight.w600,
                        prominent ? GlassColors.white : tint,
                      ).copyWith(height: 1),
                    ),
                    gap: TipMetrics.actionGap,
                  ),
                ),
            ],
          ),
        ),
        PositionedDirectional(
          top: TipMetrics.closeInset,
          end: TipMetrics.closeInset,
          child: Semantics(
            button: true,
            label: closeLabel,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onClose,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: TipMetrics.closeSize,
                height: TipMetrics.closeSize,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: TipMetrics.closeGlyphSize,
                  weight: 700,
                  color: secondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _material(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 4, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tip.image != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconTheme.merge(
                    data: IconThemeData(color: scheme.primary, size: 24),
                    child: tip.image!,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle(
                        style: theme.textTheme.titleMedium ?? const TextStyle(),
                        child: tip.title,
                      ),
                      if (tip.message != null) ...[
                        const SizedBox(height: 4),
                        DefaultTextStyle(
                          style:
                              (theme.textTheme.bodyMedium ?? const TextStyle())
                                  .copyWith(color: scheme.onSurfaceVariant),
                          child: tip.message!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: closeLabel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (tip.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 8, end: 12),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  for (final (i, action) in tip.actions.reversed.indexed)
                    i == tip.actions.length - 1
                        ? FilledButton(
                            onPressed: action.onPressed,
                            child: Text(action.label),
                          )
                        : TextButton(
                            onPressed: action.onPressed,
                            child: Text(action.label),
                          ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The actions side by side, the first (prominent) one trailing.
  Widget _actionRow(
    Widget Function(GlassTipAction action, bool prominent) build, {
    required double gap,
  }) {
    final ordered = tip.actions.reversed.toList();
    return Row(
      children: [
        for (final (i, action) in ordered.indexed) ...[
          if (i > 0) SizedBox(width: gap),
          Expanded(child: build(action, i == ordered.length - 1)),
        ],
      ],
    );
  }
}

/// An iOS capsule action that dims while pressed.
class _IOSAction extends StatefulWidget {
  const _IOSAction({
    required this.action,
    required this.fill,
    required this.labelStyle,
  });

  final GlassTipAction action;
  final Color fill;
  final TextStyle labelStyle;

  @override
  State<_IOSAction> createState() => _IOSActionState();
}

class _IOSActionState extends State<_IOSAction> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.action.onPressed,
      child: Opacity(
        opacity: _pressed ? 0.6 : 1,
        child: Container(
          height: TipMetrics.actionHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ShapeDecoration(
            color: widget.fill,
            shape: const StadiumBorder(),
          ),
          child: Text(
            widget.action.label,
            style: widget.labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ),
  );
}
