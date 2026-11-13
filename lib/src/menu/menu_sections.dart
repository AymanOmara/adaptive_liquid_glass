import 'glass_menu_item.dart';

/// One section of a menu: an optional title over its rows.
typedef MenuSection = ({String? title, List<GlassMenuItem> rows});

/// A menu's rows grouped into sections, top to bottom: each
/// [GlassMenuItem.section] is one, and the rows between them form one
/// each. A palette [GlassMenuItem.picker] is a section of its own, titled
/// with its title, whose one row is the palette. Empty sections are
/// dropped.
List<MenuSection> menuSections(List<GlassMenuItem> items) {
  final out = <MenuSection>[];
  var loose = <GlassMenuItem>[];
  void flush() {
    if (loose.isNotEmpty) out.add((title: null, rows: loose));
    loose = [];
  }

  for (final item in items) {
    if (item.isPalette) {
      flush();
      if (item.children.isNotEmpty) {
        out.add((title: item.label.isEmpty ? null : item.label, rows: [item]));
      }
      continue;
    }
    if (!item.isSection) {
      loose.add(item);
      continue;
    }
    flush();
    final rows = [
      for (final c in item.children)
        ...c.isSection ? c.children.where((r) => !r.isSection) : [c],
    ];
    if (rows.isNotEmpty || item.label.isNotEmpty) {
      out.add((title: item.label.isEmpty ? null : item.label, rows: rows));
    }
  }
  flush();
  return out;
}

/// Every row of [items] in order, sections opened up; submenus stay rows.
List<GlassMenuItem> menuRows(List<GlassMenuItem> items) => [
  for (final s in menuSections(items)) ...s.rows,
];

/// Every action of [items] in order, sections, submenus and palettes
/// opened up.
List<GlassMenuItem> menuActions(List<GlassMenuItem> items) => [
  for (final row in menuRows(items))
    ...row.isSubmenu || row.isPalette ? menuActions(row.children) : [row],
];
