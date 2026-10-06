import 'package:flutter/widgets.dart';

import 'glass_entry.dart';
import 'glass_registry.dart';
import 'render_glass_member.dart';

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
