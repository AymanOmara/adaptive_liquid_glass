import 'package:flutter/widgets.dart';

/// What a [GlassMenuItem] is: a row, a titled group of rows, or a row that
/// opens more rows.
enum _Kind { action, section, submenu }

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
       _kind = _Kind.submenu;

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

  /// A section's or a submenu's items; empty for a row.
  final List<GlassMenuItem> children;

  final _Kind _kind;

  /// Whether this is a [GlassMenuItem.section].
  bool get isSection => _kind == _Kind.section;

  /// Whether this is a [GlassMenuItem.submenu].
  bool get isSubmenu => _kind == _Kind.submenu;

  /// Whether the row responds: an action with [onSelected], or a submenu
  /// with any items. A section is not a row.
  bool get enabled => switch (_kind) {
    _Kind.action => onSelected != null,
    _Kind.submenu => children.isNotEmpty,
    _Kind.section => false,
  };
}
