import 'package:flutter/cupertino.dart';

import 'glass_menu_item.dart';
import 'menu_metrics.dart';

/// A row of a glass menu: the label at the start, the icon at the end.
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
          ? CupertinoColors.systemRed
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
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: MenuMetrics.rowPadding,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: MenuMetrics.fontSize,
                      color: color,
                    ),
                  ),
                ),
                if (item.icon != null)
                  Icon(item.icon, size: MenuMetrics.iconSize, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
