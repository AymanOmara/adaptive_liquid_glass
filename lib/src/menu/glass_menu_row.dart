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
    this.icons = true,
    this.trailing,
    this.weight = FontWeight.w400,
    this.inset = 0,
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

  /// Whether the row keeps the icon column: false when no row of its
  /// section has an icon, and the label starts at
  /// [MenuMetrics.plainLabelStart], as SwiftUI lays it out.
  final bool icons;

  /// A glyph at the row's end: a submenu's chevron.
  final IconData? trailing;

  /// The label's weight: semibold for an open submenu's own row.
  final FontWeight weight;

  /// How far the checkmark, icon and label sit from [MenuMetrics]'
  /// columns: half the difference a narrower panel makes (a context
  /// menu's, measured 1 in from a 250-pt UIKit menu's edge).
  final double inset;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(
      !item.enabled
          ? GlassColors.tertiaryLabel
          : item.destructive
          ? GlassSystemColors.red
          : item.color ?? GlassColors.label,
      context,
    );
    final style = IOSText.style(
      MenuMetrics.fontSize,
      weight: weight,
      color: color,
    );
    final scale =
        MediaQuery.textScalerOf(context).scale(MenuMetrics.fontSize) /
        MenuMetrics.fontSize;
    final labelStart =
        inset +
        (choices
            ? MenuMetrics.checkLabelStart
            : icons
            ? MenuMetrics.labelStart
            : MenuMetrics.plainLabelStart);
    final end = trailing == null
        ? MenuMetrics.trailingPadding
        : MenuMetrics.chevronCentreFromEnd + MenuMetrics.chevronSize;
    final marks = [
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
          start: inset + MenuMetrics.checkCentre - MenuMetrics.checkSize / 2,
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
          start: inset + MenuMetrics.iconCentre - MenuMetrics.iconSize / 2,
          top: 0,
          bottom: 0,
          child: Icon(item.icon, size: MenuMetrics.iconSize, color: color),
        ),
      if (trailing != null)
        PositionedDirectional(
          end: MenuMetrics.chevronCentreFromEnd - MenuMetrics.chevronSize / 2,
          top: 0,
          bottom: 0,
          child: Icon(trailing, size: MenuMetrics.chevronSize, color: color),
        ),
    ];
    return Semantics(
      container: true,
      button: true,
      enabled: item.enabled,
      selected: choices ? (item.checked ?? false) : null,
      label: item.semanticLabel ?? item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: scale > 1
            // Larger Dynamic Type: the row grows and its label wraps, as
            // iOS menus do, instead of cutting the label off.
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: double.infinity,
                  minHeight: MenuMetrics.rowHeight * scale,
                ),
                child: Stack(
                  alignment: AlignmentDirectional.centerStart,
                  children: [
                    ...marks,
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: labelStart,
                        end: end,
                        top: MenuMetrics.wrappedLabelPadding,
                        bottom: MenuMetrics.wrappedLabelPadding,
                      ),
                      child: Text(item.label, style: style),
                    ),
                  ],
                ),
              )
            : SizedBox(
                height: MenuMetrics.rowHeight,
                child: Stack(
                  children: [
                    ...marks,
                    PositionedDirectional(
                      start: labelStart,
                      end: end,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
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
