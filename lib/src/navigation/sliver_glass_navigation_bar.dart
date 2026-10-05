import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SliverAppBar;
import 'package:flutter/rendering.dart'
    show OverScrollHeaderStretchConfiguration;

import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'nav_bar_content.dart';
import 'nav_bar_metrics.dart';
import 'scroll_edge.dart';

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
        delegate: _LargeTitleDelegate(
          bar: this,
          top: MediaQuery.paddingOf(context).top,
          scale: scale,
        ),
      );
    },
  );
}

class _LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  _LargeTitleDelegate({
    required this.bar,
    required this.top,
    required this.scale,
  });

  final SliverGlassNavigationBar bar;
  final double top;
  final double scale;

  double get _titleHeight => NavBarMetrics.largeTitleHeight * scale;

  @override
  double get minExtent => top + NavBarMetrics.barHeight;

  @override
  double get maxExtent => minExtent + _titleHeight;

  @override
  OverScrollHeaderStretchConfiguration get stretchConfiguration =>
      OverScrollHeaderStretchConfiguration();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final label = CupertinoDynamicColor.resolve(CupertinoColors.label, context);
    final dir = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stretch = math.max(0.0, constraints.maxHeight - maxExtent);
        // iOS grows the large title from its leading edge when pulled.
        final grow = 1 + math.min(stretch / 400, 0.12).toDouble();
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // The large title moves with the content (up as it scrolls,
            // down as it is pulled) and is never drawn above the bar.
            Positioned.fill(
              child: ClipRect(
                clipper: _ClipBelow(top),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: minExtent - shrinkOffset + stretch,
                      height: _titleHeight,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: NavBarMetrics.largeTitleInset,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.topStart,
                          child: Transform.scale(
                            scale: grow,
                            alignment: AlignmentDirectional.bottomStart.resolve(
                              dir,
                            ),
                            child: Baseline(
                              baseline:
                                  NavBarMetrics.largeTitleBaselineBelowBar *
                                  scale,
                              baselineType: TextBaseline.alphabetic,
                              child: Semantics(
                                header: true,
                                child: DefaultTextStyle(
                                  style: TextStyle(
                                    fontSize: NavBarMetrics.largeTitleFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: label,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  child: bar.largeTitle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: GlassScrollEdge(
                visible: shrinkOffset > 0 || overlapsContent,
                blurred: shrinkOffset > NavBarMetrics.inlineThreshold,
                height: minExtent + 16,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: top,
              child: NavBarContent(
                leading: bar.leading,
                automaticallyImplyLeading: bar.automaticallyImplyLeading,
                title: bar.title ?? bar.largeTitle,
                titleOpacity: shrinkOffset > NavBarMetrics.inlineThreshold
                    ? 1.0
                    : 0.0,
                titleFade: NavBarMetrics.inlineFade,
                actions: bar.actions,
                mode: bar.mode,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  bool shouldRebuild(_LargeTitleDelegate old) =>
      old.bar != bar || old.top != top || old.scale != scale;
}

/// Clips everything above [top] (the status bar).
class _ClipBelow extends CustomClipper<Rect> {
  const _ClipBelow(this.top);

  final double top;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, top, size.width * 2, size.height * 4);

  @override
  bool shouldReclip(_ClipBelow old) => old.top != top;
}
