import 'package:flutter/cupertino.dart';

import '../core/glass_colors.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import 'glass_menu_item.dart';
import 'menu_metrics.dart';

/// A row of a glass menu: the icon at the start, then the label, as iOS
/// 26 lays them out.
class GlassMenuRow extends StatelessWidget {
  /// Creates a row for [item]; [onTap] chooses it.
  const GlassMenuRow({
    super.key,
    required this.item,
    required this.onTap,
    this.choices = false,
    this.highlighted = false,
  });

  /// The item shown.
  final GlassMenuItem item;

  /// Called when the row is tapped; null when the item is disabled.
  final VoidCallback? onTap;

  /// Whether the menu is a menu of choices: a checkmark column, the label
  /// after it.
  final bool choices;

  /// Whether a gliding finger is over the row; see [GlassMenuController].
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(
      item.onSelected == null
          ? CupertinoColors.tertiaryLabel
          : item.destructive
          ? GlassSystemColors.red
          : CupertinoColors.label,
      context,
    );
    return Semantics(
      container: true,
      button: true,
      enabled: item.onSelected != null,
      selected: choices ? (item.checked ?? false) : null,
      label: item.semanticLabel ?? item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: MenuMetrics.rowHeight,
          child: Stack(
            children: [
              if (highlighted)
                Positioned.fill(
                  child: ColoredBox(
                    color: CupertinoDynamicColor.resolve(
                      GlassColors.menuHighlight,
                      context,
                    ),
                  ),
                ),
              if (choices && (item.checked ?? false))
                PositionedDirectional(
                  start: MenuMetrics.checkCentre - MenuMetrics.checkSize / 2,
                  top: 0,
                  bottom: 0,
                  child: Icon(
                    CupertinoIcons.checkmark_alt,
                    size: MenuMetrics.checkSize,
                    color: color,
                  ),
                ),
              if (item.icon != null && !choices)
                PositionedDirectional(
                  start: MenuMetrics.iconCentre - MenuMetrics.iconSize / 2,
                  top: 0,
                  bottom: 0,
                  child: Icon(
                    item.icon,
                    size: MenuMetrics.iconSize,
                    color: color,
                  ),
                ),
              PositionedDirectional(
                start: choices
                    ? MenuMetrics.checkLabelStart
                    : MenuMetrics.labelStart,
                end: MenuMetrics.trailingPadding,
                top: 0,
                bottom: 0,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IOSText.style(MenuMetrics.fontSize, color: color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
