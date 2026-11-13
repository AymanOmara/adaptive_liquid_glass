import 'package:flutter/widgets.dart';

import '../split_view/glass_split_view_column.dart';

/// Internal. Tells a `GlassSidebarList` inside a `GlassSplitView`'s
/// sidebar column how that column shows: as a side-by-side panel
/// ([regular]) or as the first page of the compact stack, and which
/// column a selection should reveal there ([next]).
class SidebarColumnScope extends InheritedWidget {
  /// Creates the scope.
  const SidebarColumnScope({
    super.key,
    required this.regular,
    required this.next,
    required super.child,
  });

  /// Whether the sidebar sits beside the other columns.
  final bool regular;

  /// The column a selection pushes while the columns stack.
  final GlassSplitViewColumn next;

  /// The nearest scope above [context], or null outside a split view.
  static SidebarColumnScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SidebarColumnScope>();

  @override
  bool updateShouldNotify(SidebarColumnScope oldWidget) =>
      regular != oldWidget.regular || next != oldWidget.next;
}
