import 'package:flutter/widgets.dart';

import '../picker/glass_picker_style.dart';

/// What a [GlassMenuItem] is: a row, a titled group of rows, a row that
/// opens more rows, or a picker of rows.
enum _Kind { action, section, submenu, picker }

/// One item of a glass menu ([GlassMenuButton], `GlassPicker`,
/// `GlassContextMenu`).
///
/// Most items are rows: [GlassMenuItem.new]. Two more kinds group rows,
/// as SwiftUI's `Section` and nested `Menu` do:
///
/// ```dart
/// GlassMenuButton(
///   items: [
///     GlassMenuItem.section(title: 'Edit', items: [
///       GlassMenuItem(label: 'Copy', icon: CupertinoIcons.doc_on_doc,
///           onSelected: copy),
///     ]),
///     GlassMenuItem.submenu(
///       label: 'Sort By',
///       icon: CupertinoIcons.arrow_up_arrow_down,
///       items: [
///         GlassMenuItem(label: 'Name', onSelected: byName),
///         GlassMenuItem(label: 'Date', onSelected: byDate),
///       ],
///     ),
///   ],
/// )
/// ```
///
/// A divider separates sections; rows between sections form a section of
/// their own.
@immutable
class GlassMenuItem {
  /// Creates a row.
  const GlassMenuItem({
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
    this.checked,
    this.semanticLabel,
    this.color,
  }) : children = const [],
       pickerStyle = null,
       _kind = _Kind.action;

  /// A group of rows, SwiftUI's `Section`: dividers above and below it,
  /// and an optional [title] over its rows in a smaller, secondary font.
  /// Sections do not nest: a section inside one adds its rows only.
  const GlassMenuItem.section({
    String? title,
    required List<GlassMenuItem> items,
  }) : label = title ?? '',
       children = items,
       onSelected = null,
       icon = null,
       destructive = false,
       checked = null,
       semanticLabel = null,
       color = null,
       pickerStyle = null,
       _kind = _Kind.section;

  /// A row that opens [items], SwiftUI's nested `Menu`: a chevron at its
  /// end. On iOS the submenu opens over the menu, which recedes; its top
  /// row, the submenu's own label, closes it. On the Material path it is
  /// a cascading submenu.
  const GlassMenuItem.submenu({
    required this.label,
    required List<GlassMenuItem> items,
    this.icon,
    this.semanticLabel,
    this.color,
  }) : children = items,
       onSelected = null,
       destructive = false,
       checked = null,
       pickerStyle = null,
       _kind = _Kind.submenu;

  /// A picker inside the menu, SwiftUI's `Picker` in a `Menu`: [items]
  /// are its choices, [GlassMenuItem.checked] marks the current one.
  ///
  /// [style] picks the look, as `.pickerStyle` does:
  /// - [GlassPickerStyle.palette]: a horizontal row of swatches under
  ///   [title], the current one on a rounded square. A choice shows its
  ///   [icon] tinted with its [color], or a filled circle of [color].
  ///   Give each choice a [semanticLabel] or [label] for assistive tech.
  /// - [GlassPickerStyle.inline]: a [GlassMenuItem.section] of checkmark
  ///   rows.
  /// - [GlassPickerStyle.menu] and [GlassPickerStyle.navigationLink]: a
  ///   [GlassMenuItem.submenu] labelled [title].
  ///
  /// ```dart
  /// GlassMenuItem.picker(
  ///   title: 'Flag',
  ///   style: GlassPickerStyle.palette,
  ///   items: [
  ///     for (final (name, c) in flags)
  ///       GlassMenuItem(label: name, color: c, checked: flag == c,
  ///           onSelected: () => setFlag(c)),
  ///   ],
  /// )
  /// ```
  const GlassMenuItem.picker({
    String? title,
    required List<GlassMenuItem> items,
    GlassPickerStyle style = GlassPickerStyle.inline,
    this.icon,
    this.semanticLabel,
  }) : label = title ?? '',
       children = items,
       onSelected = null,
       destructive = false,
       checked = null,
       color = null,
       pickerStyle = style,
       _kind = _Kind.picker;

  /// The item's label; a section's title, empty without one.
  final String label;

  /// Called when the item is chosen, after the menu closes. Null disables
  /// the item. Always null for a section and a submenu.
  final VoidCallback? onSelected;

  /// An icon at the row's start, as iOS 26 draws it.
  final IconData? icon;

  /// Whether the action destroys data: drawn in red.
  final bool destructive;

  /// For a choice: whether it is the current one (a checkmark). Null for
  /// a plain action. A menu with any choice gives every row the
  /// checkmark column, as SwiftUI's picker menu does.
  final bool? checked;

  /// What assistive tech reads instead of [label].
  final String? semanticLabel;

  /// A tint for the label and icon (and checkmark) on both paths. Null
  /// keeps the default label colour. A disabled item stays dimmed and a
  /// [destructive] one stays red: both take precedence over [color].
  final Color? color;

  /// A section's, a submenu's or a picker's items; empty for a row.
  final List<GlassMenuItem> children;

  /// A [GlassMenuItem.picker]'s style; null for every other kind.
  final GlassPickerStyle? pickerStyle;

  final _Kind _kind;

  /// Whether this is a [GlassMenuItem.section], or an inline
  /// [GlassMenuItem.picker], which draws as one.
  bool get isSection =>
      _kind == _Kind.section ||
      (_kind == _Kind.picker && pickerStyle == GlassPickerStyle.inline);

  /// Whether this is a [GlassMenuItem.submenu], or a menu or
  /// navigation-link [GlassMenuItem.picker], which opens as one.
  bool get isSubmenu =>
      _kind == _Kind.submenu ||
      (_kind == _Kind.picker &&
          (pickerStyle == GlassPickerStyle.menu ||
              pickerStyle == GlassPickerStyle.navigationLink));

  /// Whether this is a palette [GlassMenuItem.picker]: a row of swatches.
  bool get isPalette =>
      _kind == _Kind.picker && pickerStyle == GlassPickerStyle.palette;

  /// Whether the row responds: an action with [onSelected], or a submenu
  /// with any items. A section is not a row.
  bool get enabled => switch (_kind) {
    _Kind.action => onSelected != null,
    _Kind.submenu => children.isNotEmpty,
    _Kind.section => false,
    _Kind.picker => isSubmenu && children.isNotEmpty,
  };
}
