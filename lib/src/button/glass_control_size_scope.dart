import 'package:flutter/cupertino.dart';

import 'glass_control_size.dart';

/// The default [GlassControlSize] for glass buttons below it, like
/// SwiftUI's `.controlSize(_:)`.
class GlassControlSizeScope extends InheritedWidget {
  /// Creates the scope.
  const GlassControlSizeScope({
    super.key,
    required this.size,
    required super.child,
  });

  /// The size buttons below use unless they set one.
  final GlassControlSize size;

  /// The nearest scope's size, if any.
  static GlassControlSize? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassControlSizeScope>()?.size;

  @override
  bool updateShouldNotify(GlassControlSizeScope old) => old.size != size;
}
