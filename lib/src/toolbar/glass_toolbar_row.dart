import 'package:flutter/widgets.dart';

import '../button/glass_button_metrics.dart';
import '../button/glass_button_metrics_scope.dart';
import '../core/glass_render_mode.dart';
import '../group/glass_group.dart';
import '../group/glass_union_scope.dart';
import 'glass_toolbar_spacer.dart';

/// Toolbar items in floating glass capsules: neighbours merge into one
/// capsule, a [GlassToolbarSpacer] starts a new one and pushes the groups
/// apart, and a single group is centred. Shared by `GlassToolbar` and
/// `GlassKeyboardToolbar`.
class GlassToolbarRow extends StatelessWidget {
  /// Creates the row.
  const GlassToolbarRow({
    super.key,
    required this.children,
    required this.single,
    required this.grouped,
    required this.height,
    required this.edgeInset,
    this.mode,
  });

  /// The items, with [GlassToolbarSpacer]s between groups.
  final List<Widget> children;

  /// Metrics for a lone item.
  final GlassButtonMetrics single;

  /// Metrics for an item in a group of two or more.
  final GlassButtonMetrics grouped;

  /// The capsules' height.
  final double height;

  /// The capsules' inset from the sides.
  final double edgeInset;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

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
          metrics: groups[i].length == 1 ? single : grouped,
          child: GlassUnionScope(
            id: (GlassToolbarRow, i),
            child: Row(mainAxisSize: MainAxisSize.min, children: groups[i]),
          ),
        ),
      );
    }
    // Bar items keep their size at any text size, as on iOS.
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: edgeInset),
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
