import 'package:flutter/widgets.dart';

import 'sliver_glass_navigation_bar.dart';

/// A [SliverGlassNavigationBar] over a [body] that scrolls itself: a
/// `ListView`, a paged list, a `RefreshIndicator` around one.
///
/// A scrollable in `SliverFillRemaining` takes every drag, so the large
/// title above it never collapses. This links the two, as a
/// [NestedScrollView]: scrolling the body collapses the title first.
///
/// ```dart
/// GlassLargeTitleScrollView(
///   navigationBar: const SliverGlassNavigationBar(largeTitle: Text('Inbox')),
///   body: ListView.builder(...),
/// )
/// ```
///
/// The body sits below the bar rather than under it. When the content can
/// be slivers (`SliverList`, a paged sliver list), put them in a
/// `CustomScrollView` after the bar instead, so they scroll under its
/// glass.
class GlassLargeTitleScrollView extends StatelessWidget {
  /// Creates the scroll view.
  const GlassLargeTitleScrollView({
    super.key,
    required this.navigationBar,
    required this.body,
    this.controller,
    this.physics,
  });

  /// The large-title bar.
  final SliverGlassNavigationBar navigationBar;

  /// The content; any scrollable.
  final Widget body;

  /// The outer scroll position (the title's collapse).
  final ScrollController? controller;

  /// The outer scroll physics.
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) => NestedScrollView(
    controller: controller,
    physics: physics,
    headerSliverBuilder: (context, _) => [navigationBar],
    // The bar takes the status bar; the body starts below it.
    body: MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: body,
    ),
  );
}
