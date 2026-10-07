import 'package:flutter/widgets.dart';

/// Internal. Marks a [GlassDisclosureGroup] that a list section left to
/// draw its own hairline below, since only the group knows whether its
/// last visible row is the label or an indented child.
class DisclosureSeparatorScope extends InheritedWidget {
  /// Creates the scope.
  const DisclosureSeparatorScope({super.key, required super.child});

  /// Whether a section asked the group below to draw its bottom hairline.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DisclosureSeparatorScope>() !=
      null;

  @override
  bool updateShouldNotify(DisclosureSeparatorScope old) => false;
}
