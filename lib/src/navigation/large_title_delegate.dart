import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart'
    show OverScrollHeaderStretchConfiguration;

import 'clip_below.dart';
import 'nav_bar_content.dart';
import 'nav_bar_metrics.dart';
import 'scroll_edge.dart';
import 'sliver_glass_navigation_bar.dart';

/// The pinned header of a [SliverGlassNavigationBar]: the bar, and the
/// large title that collapses into it.
class LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  /// Creates the delegate.
  LargeTitleDelegate({
    required this.bar,
    required this.top,
    required this.scale,
  });

  /// The bar's configuration.
  final SliverGlassNavigationBar bar;

  /// The status bar's height.
  final double top;

  /// The text scale applied to the large title.
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
                clipper: ClipBelow(top),
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
  bool shouldRebuild(LargeTitleDelegate old) =>
      old.bar != bar || old.top != top || old.scale != scale;
}
