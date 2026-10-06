import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show DropdownButton, DropdownMenuItem;

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import '../core/ios_text.dart';
import '../menu/glass_menu_anchor.dart';
import '../menu/glass_menu_item.dart';
import '../menu/glass_menu_placement.dart';
import 'glass_picker_item.dart';

/// iOS 26's menu-style picker, like SwiftUI's `Picker` with
/// `.pickerStyle(.menu)`: the current choice in the accent colour with an
/// up-down chevron, opening a glass menu of the choices (the current one
/// checked) centred on it.
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
/// Null [onChanged] disables it. On the Material path it is a
/// [DropdownButton].
class GlassPicker<T> extends StatelessWidget {
  /// Creates a picker.
  const GlassPicker({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.color,
    this.mode,
    this.semanticLabel,
  });

  /// The choices, top to bottom.
  final List<GlassPickerItem<T>> items;

  /// The current choice's value.
  final T selected;

  /// Called with the chosen value; null disables the picker.
  final ValueChanged<T>? onChanged;

  /// The label's colour. Defaults to iOS 26's blue, as SwiftUI draws it.
  final Color? color;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// What assistive tech reads for the picker, with the current choice as
  /// its value (say, "Period"). Without it the current choice is the label.
  final String? semanticLabel;

  /// The picker's label size (measured: 17 pt).
  static const double fontSize = 17;

  /// The up-down chevron's size.
  static const double chevronSize = 13;

  String get _label {
    for (final i in items) {
      if (i.value == selected) return i.label;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? Semantics(
            label: semanticLabel,
            child: DropdownButton<T>(
              value: selected,
              onChanged: onChanged == null ? null : (v) => onChanged!(v as T),
              items: [
                for (final i in items)
                  DropdownMenuItem(value: i.value, child: Text(i.label)),
              ],
            ),
          )
        : _glass(context),
  );

  Widget _glass(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label,
                  maxLines: 1,
                  style: IOSText.style(fontSize, color: tint),
                ),
                const SizedBox(width: 4),
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
}
