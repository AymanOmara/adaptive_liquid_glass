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
/// Material path, styled by the app's `AppBarTheme`; [materialBuilder]
/// replaces it.
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
    this.materialBuilder,
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

  /// Returns the sliver shown on the Material path in place of the default
  /// `SliverAppBar.large`, which it receives (title, leading and actions
  /// set, styling left to `AppBarTheme`). The result must be a sliver: a
  /// [SliverAppBar] of another size, or the default wrapped in one.
  ///
  /// ```dart
  /// materialBuilder: (bar) => SliverAppBar.medium(
  ///   title: bar.title,
  ///   leading: bar.leading,
  ///   actions: bar.actions,
  ///   backgroundColor: Colors.transparent,
  /// ),
  /// ```
  final Widget Function(SliverAppBar bar)? materialBuilder;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: mode,
    builder: (context, effective) {
      if (effective == EffectiveGlassMode.material) {
        final bar = SliverAppBar.large(
          title: title ?? largeTitle,
          leading: leading,
          automaticallyImplyLeading: automaticallyImplyLeading,
          actions: actions,
        );
        return materialBuilder?.call(bar) ?? bar;
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
