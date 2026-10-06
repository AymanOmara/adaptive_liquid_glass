import 'package:flutter/widgets.dart';

import '../button/glass_button_metrics_scope.dart';
import '../core/glass_render_mode.dart';
import '../group/glass_group.dart';
import '../group/glass_union_scope.dart';
import 'glass_toolbar_spacer.dart';
import 'toolbar_metrics.dart';

/// iOS 26's bottom toolbar: bar items floating in glass capsules, with no
/// bar background.
///
/// Neighbouring items merge into one capsule; a [GlassToolbarSpacer]
/// starts a new one and pushes the groups apart. A single group is
/// centred.
///
/// ```dart
/// GlassToolbar(
///   children: [
///     GlassButton.icon(onPressed: reply, icon: CupertinoIcons.reply,
///         semanticLabel: 'Reply'),
///     const GlassToolbarSpacer(),
///     GlassButton.icon(onPressed: compose, icon: CupertinoIcons.pencil,
///         semanticLabel: 'Compose'),
///   ],
/// )
/// ```
///
/// Give it to [GlassScaffold.toolbar], which floats it 28 pt above the
/// bottom. Measured from SwiftUI (`ToolbarMetrics`).
/// On the Material path its buttons are Material buttons.
class GlassToolbar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a toolbar.
  const GlassToolbar({super.key, required this.children, this.mode});

  /// The items, usually `GlassButton.icon`s, with [GlassToolbarSpacer]s
  /// between groups.
  final List<Widget> children;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Size get preferredSize => const Size.fromHeight(ToolbarMetrics.height);

  @override
  Widget build(BuildContext context) {
    final groups = <List<Widget>>[[]];
    for (final child in children) {
      if (child is GlassToolbarSpacer) {
        groups.add([]);
      } else {
        groups.last.add(child);
      }
    }
    final row = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      if (i > 0) row.add(const Spacer());
      if (groups[i].isEmpty) continue;
      row.add(
        GlassButtonMetricsScope(
          // A lone item is a circle; grouped items are a little wider.
          metrics: groups[i].length == 1
              ? ToolbarMetrics.single
              : ToolbarMetrics.grouped,
          child: GlassUnionScope(
            id: (GlassToolbar, i),
            child: Row(mainAxisSize: MainAxisSize.min, children: groups[i]),
          ),
        ),
      );
    }
    // Bar items keep their size at any text size, as on iOS.
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        height: ToolbarMetrics.height,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: ToolbarMetrics.edgeInset,
          ),
          child: GlassGroup(
            mode: mode,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row,
            ),
          ),
        ),
      ),
    );
  }
}
