import 'package:flutter/cupertino.dart';

import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import 'glass_menu_item.dart';
import 'menu_metrics.dart';

/// A row of a glass menu: the icon at the start, then the label, as iOS
/// 26 lays them out.
class GlassMenuRow extends StatelessWidget {
  /// Creates a row for [item]; [onTap] chooses it.
  const GlassMenuRow({super.key, required this.item, required this.onTap});

  /// The item shown.
  final GlassMenuItem item;

  /// Called when the row is tapped; null when the item is disabled.
  final VoidCallback? onTap;

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
      button: true,
      enabled: item.onSelected != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: MenuMetrics.rowHeight,
          child: Stack(
            children: [
              if (item.icon != null)
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
                start: MenuMetrics.labelStart,
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
