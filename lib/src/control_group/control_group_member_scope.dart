import 'package:flutter/widgets.dart';

/// Marks glass buttons below as members of a standalone `GlassControlGroup`:
/// they draw without glass, on the group's grey capsule. Internal.
class ControlGroupMemberScope extends InheritedWidget {
  /// Creates the scope.
  const ControlGroupMemberScope({super.key, required super.child});

  /// Whether [context] is inside a standalone group.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ControlGroupMemberScope>() !=
      null;

  @override
  bool updateShouldNotify(ControlGroupMemberScope old) => false;
}
