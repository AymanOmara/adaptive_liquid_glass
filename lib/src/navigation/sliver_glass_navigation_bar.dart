import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SliverAppBar;

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'glass_large_title_scroll_view.dart';
import 'glass_scroll_edge_style.dart';
import 'large_title_delegate.dart';
import 'nav_bar_metrics.dart';

/// iOS 26's large-title navigation bar for a `CustomScrollView`.
///
/// The large title scrolls up with the content under the bar; once it has
/// gone (past [NavBarMetrics.inlineThreshold]) the inline title fades in.
/// Pulling down stretches the large title. `SliverAppBar.large` on the
/// Material path.
///
/// ```dart
/// CustomScrollView(slivers: [
///   SliverGlassNavigationBar(largeTitle: const Text('Inbox')),
///   SliverList(...),
/// ])
/// ```
///
/// The bar collapses as its scroll view scrolls. A scrollable placed in
/// `SliverFillRemaining` scrolls on its own, so the title never collapses;
/// use slivers, or [GlassLargeTitleScrollView] for such a body.
class SliverGlassNavigationBar extends StatelessWidget {
  /// Creates a large-title bar.
  const SliverGlassNavigationBar({
    super.key,
    required this.largeTitle,
    this.title,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions = const [],
    this.mode,
    this.scrollEdgeStyle = GlassScrollEdgeStyle.uniform,
  });

  /// The large title below the bar.
  final Widget largeTitle;

  /// The inline title; defaults to [largeTitle].
  final Widget? title;

  /// Defaults to a `GlassBackButton` when the route can pop.
  final Widget? leading;

  /// Whether to add the default back button.
  final bool automaticallyImplyLeading;

  /// Trailing items, merged into one capsule.
  final List<Widget> actions;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// How content scrolled under the bar is blurred; see
  /// [GlassScrollEdgeStyle].
  final GlassScrollEdgeStyle scrollEdgeStyle;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) {
      if (effective == EffectiveGlassMode.material) {
        return SliverAppBar.large(
          title: title ?? largeTitle,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          actions: actions,
        );
      }
      final scale =
          MediaQuery.textScalerOf(
            context,
          ).scale(NavBarMetrics.largeTitleFontSize) /
          NavBarMetrics.largeTitleFontSize;
      return SliverPersistentHeader(
        pinned: true,
        delegate: LargeTitleDelegate(
          bar: this,
          top: MediaQuery.paddingOf(context).top,
          scale: scale,
        ),
      );
    },
  );
}
