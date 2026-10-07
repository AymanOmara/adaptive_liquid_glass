import 'package:flutter/cupertino.dart';

import '../core/glass_render_mode.dart';
import '../list/glass_list_section.dart';
import '../list/list_metrics.dart';
import '../navigation/glass_navigation_bar.dart';
import '../scaffold/glass_scaffold.dart';
import 'glass_picker.dart';
import 'glass_picker_item.dart';
import 'glass_picker_style.dart';

/// Internal. The page a navigation-link picker pushes: the label as the
/// title over a grouped list of the choices, popping with the one tapped.
class PickerPage<T> extends StatelessWidget {
  /// Creates the page.
  const PickerPage({
    super.key,
    required this.title,
    required this.items,
    required this.selected,
    this.color,
    this.mode,
  });

  /// The navigation bar's title: the picker's label.
  final Widget title;

  /// The choices, top to bottom.
  final List<GlassPickerItem<T>> items;

  /// The current choice's value.
  final T selected;

  /// The checkmark's colour; null takes the accent.
  final Color? color;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) => GlassScaffold(
    navigationBar: GlassNavigationBar(title: title, mode: mode),
    backgroundColor: CupertinoDynamicColor.resolve(
      CupertinoColors.systemGroupedBackground,
      context,
    ),
    // The scaffold grows the body's padding by the bar, so the list
    // starts clear of it.
    body: Builder(
      builder: (context) => ListView(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + ListMetrics.margin,
          bottom: MediaQuery.paddingOf(context).bottom + ListMetrics.margin,
        ),
        children: [
          GlassListSection(
            mode: mode,
            children: [
              GlassPicker<T>(
                style: GlassPickerStyle.inline,
                items: items,
                selected: selected,
                color: color,
                mode: mode,
                onChanged: (v) => Navigator.of(context).pop(v),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
