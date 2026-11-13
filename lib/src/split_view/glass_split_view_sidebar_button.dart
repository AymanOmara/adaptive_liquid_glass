import 'package:flutter/cupertino.dart';

import '../button/glass_button.dart';
import '../button/glass_button_metrics_scope.dart';
import '../button/glass_button_style.dart';
import '../core/glass_render_mode.dart';
import '../navigation/nav_bar_metrics.dart';
import 'glass_split_view.dart';
import 'glass_split_view_column.dart';
import 'glass_split_view_controller.dart';

/// The button `NavigationSplitView` puts in the sidebar's toolbar: it hides
/// the sidebar, or shows it again.
///
/// It is a toolbar item, sized as one: SwiftUI's glyph is ~24.5 × 19 pt of
/// ink on iPadOS 26.4 (gap-split-swiftui.png), which the bar items' 26-pt
/// icon reproduces. A plain icon button at its default size is ~37% smaller.
///
/// ```dart
/// GlassSplitView(
///   sidebar: Column(children: [
///     Align(
///       alignment: AlignmentDirectional.centerEnd,
///       child: GlassSplitViewSidebarButton(),
///     ),
///     ...
///   ]),
///   detail: detail,
/// )
/// ```
class GlassSplitViewSidebarButton extends StatelessWidget {
  /// Creates the button. Without a [controller] it drives the nearest
  /// [GlassSplitView].
  const GlassSplitViewSidebarButton({
    super.key,
    this.controller,
    this.foregroundColor,
    this.mode,
  });

  /// The split view to drive; defaults to `GlassSplitView.of(context)`.
  final GlassSplitViewController? controller;

  /// The glyph's colour; defaults to the label colour.
  final Color? foregroundColor;

  /// The rendering path; null takes the theme's default.
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    final c = controller ?? GlassSplitView.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => GlassButtonMetricsScope(
        metrics: NavBarMetrics.loneItem,
        child: GlassButton.icon(
          onPressed: c.toggleSidebar,
          style: GlassButtonStyle.plain,
          mode: mode,
          icon: CupertinoIcons.sidebar_left,
          semanticLabel: c.visibility == GlassSplitViewVisibility.detailOnly
              ? 'Show Sidebar'
              : 'Hide Sidebar',
          foregroundColor:
              foregroundColor ??
              CupertinoDynamicColor.resolve(CupertinoColors.label, context),
        ),
      ),
    );
  }
}
