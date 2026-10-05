import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'glass_entry.dart';
import 'glass_registry.dart';

/// Provides the enclosing glass entry to concentric descendants.
class ConcentricScope extends InheritedWidget {
  /// Creates the scope.
  const ConcentricScope({super.key, required this.entry, required super.child});

  /// The enclosing glass.
  final GlassEntry entry;

  /// Nearest enclosing entry.
  static GlassEntry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConcentricScope>()?.entry;

  @override
  bool updateShouldNotify(ConcentricScope old) => old.entry != entry;
}

/// Hands its render box to the entry and reports geometry changes.
class GlassMemberBox extends SingleChildRenderObjectWidget {
  /// Creates the box.
  const GlassMemberBox({
    super.key,
    required this.entry,
    required this.registry,
    super.child,
  });

  /// The member's entry.
  final GlassEntry entry;

  /// The member's registry.
  final GlassRegistry registry;

  @override
  RenderGlassMember createRenderObject(BuildContext context) {
    final r = RenderGlassMember(entry, registry);
    entry.box = r;
    return r;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassMember renderObject,
  ) {
    renderObject
      ..entry = entry
      ..registry = registry;
    entry.box = renderObject;
  }
}

/// See [GlassMemberBox].
class RenderGlassMember extends RenderProxyBox {
  /// Creates the render object.
  RenderGlassMember(this.entry, this.registry);

  /// The member's entry.
  GlassEntry entry;

  /// The member's registry.
  GlassRegistry registry;

  Matrix4? _lastTransform;

  @override
  void performLayout() {
    final old = hasSize ? size : null;
    super.performLayout();
    if (old != size) registry.markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // This member repainted at a new global transform. The group may not
    // have repainted this frame (a repaint boundary sits between us), so
    // refresh it one frame late; the post-frame markNeedsPaint schedules
    // that frame. A boundary that only moves its layer does not re-run this
    // paint at all: scrolling is covered by the scroll listeners in
    // GlassGroup and GlassMemberState, and route motion by GlassGroup.
    final t = getTransformTo(null);
    if (_lastTransform != null && _lastTransform != t) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (attached) registry.markNeedsPaint();
      });
    }
    _lastTransform = t;
  }
}
