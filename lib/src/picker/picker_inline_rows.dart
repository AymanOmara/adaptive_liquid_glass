import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Divider, Icons, ListTile, MaterialBasedCupertinoThemeData, Theme;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import '../list/glass_list_tile.dart';
import '../list/list_metrics.dart';
import 'glass_picker_item.dart';
import 'picker_metrics.dart';

/// Internal. The inline picker's rows: one `GlassListTile` per choice,
/// the current one ending in a checkmark, with hairlines between them
/// (a section separates only its direct children). On the Material path
/// they are [ListTile]s divided by [Divider]s.
class PickerInlineRows<T> extends StatelessWidget {
  /// Creates the rows.
  const PickerInlineRows({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    required this.effective,
    this.color,
    this.mode,
  });

  /// The choices, top to bottom.
  final List<GlassPickerItem<T>> items;

  /// The current choice's value.
  final T selected;

  /// Called with the chosen value; null disables the rows.
  final ValueChanged<T>? onChanged;

  /// The path the picker resolved.
  final EffectiveGlassMode effective;

  /// The checkmark's colour; null takes the accent.
  final Color? color;

  /// The rendering path handed to the rows.
  final GlassRenderMode? mode;

  bool get _enabled => onChanged != null;

  /// One row, merged into one semantics node that reads as a selectable
  /// button, like a radio choice.
  Widget _row(Widget tile, GlassPickerItem<T> item) => MergeSemantics(
    child: Semantics(
      button: true,
      enabled: _enabled,
      selected: item.value == selected,
      inMutuallyExclusiveGroup: true,
      child: tile,
    ),
  );

  @override
  Widget build(BuildContext context) => effective == EffectiveGlassMode.material
      ? _material(context)
      : _glass(context);

  Widget _material(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          _row(
            ListTile(
              title: Text(items[i].label),
              trailing: items[i].value == selected
                  ? Icon(Icons.check, color: accent)
                  : null,
              selected: items[i].value == selected,
              enabled: _enabled,
              onTap: _enabled ? () => onChanged!(items[i].value) : null,
            ),
            items[i],
          ),
          if (i < items.length - 1)
            const Divider(height: 1, indent: ListMetrics.materialInset),
        ],
      ],
    );
  }

  /// The checkmark's tint: the accent, the theme's primary colour when
  /// customized, or a dim grey while disabled; as the list icon's.
  Color _checkColor(BuildContext context) {
    if (!_enabled) {
      return CupertinoDynamicColor.resolve(
        CupertinoColors.tertiaryLabel,
        context,
      );
    }
    if (color != null) return CupertinoDynamicColor.resolve(color!, context);
    final theme = CupertinoTheme.of(context);
    // Under a MaterialApp the Cupertino theme is derived from the Material
    // colour scheme; only an explicit cupertinoOverrideTheme colour counts.
    final Color? primary = theme is MaterialBasedCupertinoThemeData
        ? Theme.of(context).cupertinoOverrideTheme?.primaryColor
        : theme.primaryColor;
    final defaultBlue = CupertinoDynamicColor.resolve(
      CupertinoColors.activeBlue,
      context,
    );
    if (primary == null || primary == defaultBlue) {
      return CupertinoDynamicColor.resolve(GlassSystemColors.blue, context);
    }
    return CupertinoDynamicColor.resolve(primary, context);
  }

  Widget _glass(BuildContext context) {
    final separatorColor = CupertinoDynamicColor.resolve(
      GlassColors.listSeparator,
      context,
    );
    final check = Icon(
      CupertinoIcons.checkmark_alt,
      size: PickerMetrics.checkSize,
      color: _checkColor(context),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          _withSeparator(
            _row(
              GlassListTile(
                title: Text(items[i].label),
                trailing: items[i].value == selected ? check : null,
                enabled: _enabled,
                mode: mode,
                onTap: _enabled ? () => onChanged!(items[i].value) : null,
              ),
              items[i],
            ),
            i < items.length - 1 ? separatorColor : null,
          ),
      ],
    );
  }

  /// [row] with a hairline overlaid on its bottom edge when [color] is
  /// set; the last row leaves that to the section.
  Widget _withSeparator(Widget row, Color? color) => color == null
      ? row
      : Stack(
          children: [
            row,
            PositionedDirectional(
              start: ListMetrics.horizontalPadding,
              end: ListMetrics.separatorEnd,
              bottom: 0,
              height: ListMetrics.separatorThickness,
              child: ColoredBox(color: color),
            ),
          ],
        );
}
