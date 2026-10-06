import 'package:flutter/widgets.dart';

import '../core/glass_render_mode.dart';

/// Internal. The list section's defaults for the tiles below it.
class ListSectionScope extends InheritedWidget {
  /// Creates the scope.
  const ListSectionScope({
    super.key,
    required this.mode,
    required this.glass,
    required super.child,
  });

  /// The rendering path tiles below take by default.
  final GlassRenderMode? mode;

  /// Whether the section's platter is glass.
  final bool glass;

  /// The nearest scope, if any.
  static ListSectionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ListSectionScope>();

  @override
  bool updateShouldNotify(ListSectionScope old) =>
      old.mode != mode || old.glass != glass;
}
