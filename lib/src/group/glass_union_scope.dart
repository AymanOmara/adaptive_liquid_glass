import 'package:flutter/widgets.dart';

/// Glass below without its own `unionId` merges under [id], like wrapping
/// each in `glassEffectUnion(id:)`. Used for grouped bar buttons.
class GlassUnionScope extends InheritedWidget {
  /// Creates the scope.
  const GlassUnionScope({super.key, required this.id, required super.child});

  /// The union id glass below takes by default.
  final Object id;

  /// The nearest scope's id, if any.
  static Object? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassUnionScope>()?.id;

  @override
  bool updateShouldNotify(GlassUnionScope old) => old.id != id;
}
