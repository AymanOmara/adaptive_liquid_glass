import 'package:flutter/widgets.dart';

import '../core/glass_render_mode.dart';
import 'glass_toolbar_row.dart';
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
  Widget build(BuildContext context) => GlassToolbarRow(
    single: ToolbarMetrics.single,
    grouped: ToolbarMetrics.grouped,
    height: ToolbarMetrics.height,
    edgeInset: ToolbarMetrics.edgeInset,
    mode: mode,
    children: children,
  );
}
