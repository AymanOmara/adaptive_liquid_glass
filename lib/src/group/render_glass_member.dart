import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'glass_entry.dart';
import 'glass_member_box.dart';
import 'glass_registry.dart';

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
