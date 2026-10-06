import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show PopupMenuItem, RelativeRect, showMenu;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/cupertino_l10n.dart';
import '../core/effective_glass_mode.dart';
import '../core/glass_render_mode.dart';
import '../core/render_mode_resolver.dart';
import '../core/theme.dart';
import '../menu/glass_menu_item.dart';
import '../platform/glass_platform.dart';
import 'glass_context_menu_route.dart';

/// iOS 26's context menu, like SwiftUI's `.contextMenu`: a long-press
/// lifts [child] over the blurred page and opens the glass menu of
/// [items] by it.
///
/// ```dart
/// GlassContextMenu(
///   items: [
///     GlassMenuItem(label: 'Copy', icon: CupertinoIcons.doc_on_doc,
///         onSelected: copy),
///     GlassMenuItem(label: 'Delete', icon: CupertinoIcons.trash,
///         destructive: true, onSelected: delete),
///   ],
///   child: photo,
/// )
/// ```
///
/// A tap outside closes it; choosing an item closes it, then runs the
/// item. Assistive tech gets the items as custom actions. On the Material
/// path the long-press opens a Material popup menu. Not measured against
/// SwiftUI (see `ContextMenuMetrics`).
class GlassContextMenu extends StatelessWidget {
  /// Creates a context menu for [child].
  const GlassContextMenu({
    super.key,
    required this.items,
    required this.child,
    this.mode,
  });

  /// The menu's rows.
  final List<GlassMenuItem> items;

  /// The item long-pressed.
  final Widget child;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  Future<void> _open(BuildContext context, Offset at) async {
    HapticFeedback.heavyImpact();
    final effective = resolveGlassMode(
      requested: mode ?? LiquidGlassTheme.of(context).defaultMode,
      environment: GlassPlatform.instance.environment.value,
    );
    final box = context.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    GlassMenuItem? chosen;
    if (effective == EffectiveGlassMode.material) {
      final screen = MediaQuery.sizeOf(context);
      chosen = await showMenu<GlassMenuItem>(
        context: context,
        position: RelativeRect.fromLTRB(
          at.dx,
          at.dy,
          screen.width - at.dx,
          screen.height - at.dy,
        ),
        items: [
          for (final item in items)
            PopupMenuItem(
              value: item,
              enabled: item.onSelected != null,
              child: Text(item.label),
            ),
        ],
      );
    } else {
      chosen = await Navigator.of(context).push(
        GlassContextMenuRoute(
          preview: child,
          previewRect: rect,
          items: items,
          mode: mode,
          barrierLabel: cupertinoL10n(context).modalBarrierDismissLabel,
        ),
      );
    }
    chosen?.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: {
      for (final item in items)
        if (item.onSelected != null)
          CustomSemanticsAction(label: item.label): item.onSelected!,
    },
    child: GestureDetector(
      onLongPressStart: (d) => _open(context, d.globalPosition),
      child: child,
    ),
  );
}
