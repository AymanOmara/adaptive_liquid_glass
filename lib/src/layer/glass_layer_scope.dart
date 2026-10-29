import 'package:flutter/widgets.dart';

import '../platform/glass_platform.dart';
import 'glass_layer.dart';
import 'glass_layer_slot.dart';

/// Keeps Android shader glass batching inside [child]'s paint subtree.
///
/// Wrap the content returned by a route's builder to keep one shared glass
/// layer while a transition snapshots, scales or fades that page. The layer
/// travels with the page instead of painting in the route's overlay.
///
/// It also supports glass in a composited follower, such as an anchored menu.
/// The nearest scope owns its groups; nested scopes draw independently. Like
/// the route's automatic layer, later non-glass siblings that cover glass
/// should use `GlassOverlayContent` to preserve their paint order.
///
/// On platforms without shared shader layers this passes [child] through.
class GlassLayerScope extends StatefulWidget {
  /// Creates a shared layer local to [child].
  const GlassLayerScope({super.key, required this.child});

  /// The route content, menu or other subtree sharing one layer.
  final Widget child;

  /// The nearest scope's layer, or null without a scope.
  static GlassLayer? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_GlassLayerScopeData>();
    if (scope == null) return null;
    // A scope inside an opt-out (a menu's follower) owns a local layer.
    // A new opt-out below that scope still takes effect.
    final optOut = context
        .getElementForInheritedWidgetOfExactType<GlassLayerOptOut>();
    return identical(optOut, scope.optOut) ? scope.layer : null;
  }

  @override
  State<GlassLayerScope> createState() => _GlassLayerScopeState();
}

class _GlassLayerScopeState extends State<GlassLayerScope> {
  late final GlassLayer _layer = GlassLayer.of(this);

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: GlassPlatform.instance.environment,
    builder: (context, environment, _) {
      if (!GlassSharedLayer.enabledFor(environment.platform)) {
        return widget.child;
      }
      return _GlassLayerScopeData(
        layer: _layer,
        optOut: context
            .getElementForInheritedWidgetOfExactType<GlassLayerOptOut>(),
        child: Stack(
          alignment: Alignment.topLeft,
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: GlassLayerSlot(layer: _layer, repaintBoundary: false),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _GlassLayerScopeData extends InheritedWidget {
  const _GlassLayerScopeData({
    required this.layer,
    required this.optOut,
    required super.child,
  });

  final GlassLayer layer;
  final InheritedElement? optOut;

  @override
  bool updateShouldNotify(_GlassLayerScopeData oldWidget) =>
      !identical(layer, oldWidget.layer) ||
      !identical(optOut, oldWidget.optOut);
}
