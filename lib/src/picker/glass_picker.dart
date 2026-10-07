import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show DropdownButton, DropdownMenuItem, MaterialPageRoute;

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import '../list/glass_list_tile.dart';
import '../menu/glass_menu_anchor.dart';
import '../menu/glass_menu_item.dart';
import '../menu/glass_menu_placement.dart';
import 'glass_picker_item.dart';
import 'glass_picker_style.dart';
import 'picker_inline_rows.dart';
import 'picker_metrics.dart';
import 'picker_page.dart';

/// iOS 26's picker, like SwiftUI's `Picker`. By default (the menu
/// [style]) it is the current choice in the accent colour with an up-down
/// chevron, opening a glass menu of the choices (the current one checked)
/// centred on it.
///
/// ```dart
/// GlassPicker<Period>(
///   items: const [
///     GlassPickerItem(value: Period.day, label: 'Day'),
///     GlassPickerItem(value: Period.week, label: 'Week'),
///   ],
///   selected: period,
///   onChanged: (p) => setState(() => period = p),
/// )
/// ```
///
/// [GlassPickerStyle.inline] lays the choices out as list rows, the
/// current one with a checkmark, for a `GlassListSection`:
///
/// ```dart
/// GlassListSection(
///   header: const Text('Period'),
///   children: [
///     GlassPicker<Period>(
///       style: GlassPickerStyle.inline,
///       items: periods,
///       selected: period,
///       onChanged: (p) => setState(() => period = p),
///     ),
///   ],
/// )
/// ```
///
/// [GlassPickerStyle.navigationLink] is one row showing the [label], the
/// current choice and a chevron; tapping it pushes a page of the choices
/// that pops as soon as one is tapped, as iOS Settings does:
///
/// ```dart
/// GlassPicker<Period>(
///   style: GlassPickerStyle.navigationLink,
///   label: const Text('Period'),
///   items: periods,
///   selected: period,
///   onChanged: (p) => setState(() => period = p),
/// )
/// ```
///
/// Null [onChanged] disables it. On the Material path the menu style is a
/// [DropdownButton], the rows are Material 3 `ListTile`s, and the
/// navigation link pushes a Material page.
class GlassPicker<T> extends StatelessWidget {
  /// Creates a picker.
  const GlassPicker({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.style = GlassPickerStyle.menu,
    this.label,
    this.color,
    this.mode,
    this.semanticLabel,
  }) : assert(
         style != GlassPickerStyle.navigationLink || label != null,
         'A navigation-link picker needs a label for its row and page.',
       );

  /// The choices, top to bottom.
  final List<GlassPickerItem<T>> items;

  /// The current choice's value.
  final T selected;

  /// Called with the chosen value; null disables the picker.
  final ValueChanged<T>? onChanged;

  /// How the choices are presented; see [GlassPickerStyle].
  final GlassPickerStyle style;

  /// The navigation-link row's title and its page's title, like
  /// [GlassListTile.title]; required by that style and unused by the
  /// others (the inline rows take their section's header).
  final Widget? label;

  /// The menu label's or the checkmark's colour. Defaults to iOS 26's
  /// blue, as SwiftUI draws it.
  final Color? color;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// What assistive tech reads for the picker, with the current choice as
  /// its value (say, "Period"). Without it the current choice is the label
  /// (the navigation-link row reads its [label] and value).
  final String? semanticLabel;

  /// The picker's label size (measured: 17 pt).
  static const double fontSize = PickerMetrics.fontSize;

  /// The up-down chevron's size.
  static const double chevronSize = PickerMetrics.chevronSize;

  String get _label {
    for (final i in items) {
      if (i.value == selected) return i.label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => switch (style) {
      GlassPickerStyle.menu =>
        effective == EffectiveGlassMode.material
            ? _materialMenu()
            : _glassMenu(context),
      GlassPickerStyle.inline => PickerInlineRows<T>(
        items: items,
        selected: selected,
        onChanged: onChanged,
        effective: effective,
        color: color,
        mode: mode,
      ),
      GlassPickerStyle.navigationLink => _link(context, effective),
    },
  );

  Widget _materialMenu() => Semantics(
    label: semanticLabel,
    child: DropdownButton<T>(
      value: selected,
      onChanged: onChanged == null ? null : (v) => onChanged!(v as T),
      items: [
        for (final i in items)
          DropdownMenuItem(value: i.value, child: Text(i.label)),
      ],
    ),
  );

  Widget _glassMenu(BuildContext context) {
    final enabled = onChanged != null;
    final tint = CupertinoDynamicColor.resolve(
      enabled ? color ?? GlassSystemColors.blue : CupertinoColors.tertiaryLabel,
      context,
    );
    return GlassMenuAnchor(
      placement: GlassMenuPlacement.centred,
      mode: mode,
      items: [
        for (final i in items)
          GlassMenuItem(
            label: i.label,
            checked: i.value == selected,
            onSelected: enabled ? () => onChanged!(i.value) : null,
          ),
      ],
      // One node: the visible choice is its label, or its value under an
      // explicit label; never both.
      builder: (context, open) => Semantics(
        container: true,
        button: true,
        enabled: enabled,
        label: semanticLabel ?? _label,
        value: semanticLabel == null ? null : _label,
        onTap: enabled ? open : null,
        excludeSemantics: true,
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? open : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: PickerMetrics.verticalPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label,
                  maxLines: 1,
                  style: IOSText.style(fontSize, color: tint),
                ),
                const SizedBox(width: PickerMetrics.chevronGap),
                Icon(
                  CupertinoIcons.chevron_up_chevron_down,
                  size: chevronSize,
                  color: tint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The navigation-link row: the label, the current choice as the
  /// value, a chevron. An explicit [semanticLabel] replaces the merged
  /// row text.
  Widget _link(BuildContext context, EffectiveGlassMode effective) {
    final enabled = onChanged != null;
    return MergeSemantics(
      child: Semantics(
        label: semanticLabel,
        value: semanticLabel == null ? null : _label,
        excludeSemantics: semanticLabel != null,
        button: true,
        enabled: enabled,
        child: GlassListTile(
          title: label!,
          value: _label,
          chevron: true,
          enabled: enabled,
          mode: mode,
          onTap: enabled ? () => _push(context, effective) : null,
        ),
      ),
    );
  }

  /// Pushes the page of choices on the host's navigator and reports the
  /// one it pops with, if any. iOS's push slides; under Reduce Motion the
  /// page appears in place.
  Future<void> _push(BuildContext context, EffectiveGlassMode effective) async {
    final page = PickerPage<T>(
      title: label!,
      items: items,
      selected: selected,
      color: color,
      mode: mode,
    );
    final Route<T> route;
    if (MediaQuery.disableAnimationsOf(context)) {
      route = PageRouteBuilder<T>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => page,
      );
    } else if (effective == EffectiveGlassMode.material) {
      route = MaterialPageRoute<T>(builder: (_) => page);
    } else {
      route = CupertinoPageRoute<T>(builder: (_) => page);
    }
    final picked = await Navigator.of(context).push<T>(route);
    if (picked != null) onChanged?.call(picked);
  }
}
