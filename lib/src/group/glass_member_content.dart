import 'package:flutter/widgets.dart';

import 'glass_group_scope.dart';
import 'glass_registry.dart';

/// Marks the content of a `LiquidGlass` that made its own group. Internal.
///
/// Glass inside that content is layered on the glass, like a SwiftUI
/// `.glassEffect` button on a `.glassEffect` card, so it makes a group of
/// its own instead of joining the card's: in one group (one
/// `GlassEffectContainer` on iOS 26, one shader pass elsewhere) the two
/// shapes blend and the inner glass loses its edge and rim. Glass whose
/// group is an explicit `GlassGroup` marks nothing, so nested glass joins
/// that group, as the app asked.
class GlassMemberContent extends InheritedWidget {
  /// Marks [child] as content of glass registered with [registry], or, when
  /// null, as content that nested glass may join.
  const GlassMemberContent({
    super.key,
    required this.registry,
    required super.child,
  });

  /// Wraps [child] with the registry of the group at that point when
  /// [isolating]. The tree has the same shape either way.
  static Widget wrap({required bool isolating, required Widget child}) =>
      Builder(
        builder: (context) => GlassMemberContent(
          registry: isolating ? GlassGroupScope.of(context).registry : null,
          child: child,
        ),
      );

  /// The registry of the glass whose content this is, when nested glass
  /// must not join it.
  final GlassRegistry? registry;

  /// Whether [context] sits in the content of glass in [scope]'s group that
  /// nested glass must not join.
  static bool isInsideMemberOf(BuildContext context, GlassGroupScope scope) =>
      identical(
        context
            .dependOnInheritedWidgetOfExactType<GlassMemberContent>()
            ?.registry,
        scope.registry,
      );

  @override
  bool updateShouldNotify(GlassMemberContent oldWidget) =>
      !identical(oldWidget.registry, registry);
}
