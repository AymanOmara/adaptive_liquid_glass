import 'package:flutter/widgets.dart';

import 'search_metrics.dart';

/// The search field's capsule size and its inner insets for the fields
/// under it: the bottom field's unless a placement says otherwise.
class SearchFieldSize extends InheritedWidget {
  /// Gives the fields under [child] these sizes.
  const SearchFieldSize({
    super.key,
    required this.height,
    required this.startInset,
    required this.endInset,
    required super.child,
  });

  /// The navigation-bar drawer's field (measured).
  const SearchFieldSize.drawer({super.key, required super.child})
    : height = SearchMetrics.drawerHeight,
      startInset = SearchMetrics.drawerStartInset,
      endInset = SearchMetrics.drawerEndInset;

  /// The capsule's height before Dynamic Type growth.
  final double height;

  /// The magnifying glass's inset from the start.
  final double startInset;

  /// The clear button's inset from the end.
  final double endInset;

  /// The sizes in force at [context].
  static SearchFieldSize? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SearchFieldSize>();

  @override
  bool updateShouldNotify(SearchFieldSize old) =>
      height != old.height ||
      startInset != old.startInset ||
      endInset != old.endInset;
}
