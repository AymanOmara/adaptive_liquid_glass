import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../button/glass_button_metrics_scope.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../group/glass_group.dart';
import '../group/glass_union_scope.dart';
import '../toolbar/glass_toolbar_spacer.dart';
import 'glass_back_button.dart';
import 'glass_bar_item.dart';
import 'nav_bar_metrics.dart';

/// The bar row shared by both navigation bars: leading item, centred
/// title, trailing actions merged into glass capsules (one per group). No
/// safe area.
class NavBarContent extends StatelessWidget {
  /// Creates the row.
  const NavBarContent({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.subtitle,
    this.titleOpacity = 1,
    this.titleFade,
    this.actions = const [],
    this.mode,
  });

  /// Leading item; defaults to a back button when the route can pop.
  final Widget? leading;

  /// Whether to add the default back button.
  final bool automaticallyImplyLeading;

  /// The inline title.
  final Widget? title;

  /// The subtitle under the inline title.
  final Widget? subtitle;

  /// The inline title's opacity.
  final double titleOpacity;

  /// When set, opacity changes animate over this long.
  final Duration? titleFade;

  /// Trailing items, merged into one capsule; a [GlassToolbarSpacer]
  /// starts a new one and a [GlassBarItem] with no shared background
  /// stands alone with none.
  final List<Widget> actions;

  /// Rendering mode for the bar's glass.
  final GlassRenderMode? mode;

  static const Object _actionsUnion = Object();

  Widget _fade(Widget child) => titleFade == null
      ? Opacity(opacity: titleOpacity, child: child)
      : AnimatedOpacity(
          opacity: titleOpacity,
          duration: titleFade!,
          // iOS 26 brings the inline title in blurred and sharpens it.
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: titleOpacity),
            duration: titleFade!,
            child: child,
            builder: (context, v, child) {
              final sigma = (1 - v) * 4;
              return ImageFiltered(
                enabled: sigma > 0.05,
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: child,
              );
            },
          ),
        );

  /// The actions as groups: each its own glass capsule (a union), a group
  /// of one a 44-pt circle as SwiftUI's lone bar button, a bare item a
  /// 44-pt cell with no glass; [NavBarMetrics.groupGap] between them.
  Widget? _trailing(Widget Function(Widget) item) {
    final groups = <List<Widget>>[[]];
    for (final action in actions) {
      if (action is GlassToolbarSpacer) {
        groups.add([]);
      } else if (action is GlassBarItem && !action.sharedBackground) {
        groups
          ..add([action])
          ..add([]);
      } else {
        groups.last.add(action);
      }
    }
    final row = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      if (group.isEmpty) continue;
      if (row.isNotEmpty) {
        row.add(const SizedBox(width: NavBarMetrics.groupGap));
      }
      final first = group.first;
      row.add(
        first is GlassBarItem && !first.sharedBackground
            ? SizedBox.square(
                dimension: NavBarMetrics.bareItemSize,
                child: Center(child: first),
              )
            : GlassButtonMetricsScope(
                metrics: group.length == 1
                    ? NavBarMetrics.loneItem
                    : NavBarMetrics.item,
                child: GlassUnionScope(
                  id: (_actionsUnion, i),
                  child: Row(mainAxisSize: MainAxisSize.min, children: group),
                ),
              ),
      );
    }
    if (row.isEmpty) return null;
    return GlassGroup(
      mode: mode,
      child: item(Row(mainAxisSize: MainAxisSize.min, children: row)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead =
        leading ??
        (automaticallyImplyLeading && glassCanImplyBack(context)
            ? GlassBackButton(mode: mode)
            : null);
    final label = CupertinoDynamicColor.resolve(GlassColors.label, context);
    // Bar items and the inline title keep their size at any text size, as
    // on iOS (the bar's height is fixed).
    Widget item(Widget child) => MediaQuery.withNoTextScaling(child: child);
    return GlassButtonMetricsScope(
      metrics: NavBarMetrics.item,
      child: SizedBox(
        height: NavBarMetrics.barHeight,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: NavBarMetrics.edgeInset,
          ),
          child: NavigationToolbar(
            // The toolbar stretches its leading slot to the bar's height.
            leading: lead == null
                ? null
                : Center(
                    widthFactor: 1,
                    child: GlassButtonMetricsScope(
                      metrics: NavBarMetrics.loneItem,
                      child: item(lead),
                    ),
                  ),
            middle: title == null
                ? null
                : _fade(
                    Semantics(
                      header: true,
                      child: MediaQuery.withClampedTextScaling(
                        maxScaleFactor: NavBarMetrics.titleMaxTextScale,
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontSize: NavBarMetrics.titleFontSize,
                            fontWeight: FontWeight.w600,
                            color: label,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: subtitle == null
                              ? title!
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    title!,
                                    DefaultTextStyle(
                                      style: TextStyle(
                                        fontSize:
                                            NavBarMetrics.subtitleFontSize,
                                        fontWeight: FontWeight.w400,
                                        color: CupertinoDynamicColor.resolve(
                                          GlassColors.secondaryLabel,
                                          context,
                                        ),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      child: subtitle!,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
            trailing: _trailing(item),
            middleSpacing: 8,
          ),
        ),
      ),
    );
  }
}
