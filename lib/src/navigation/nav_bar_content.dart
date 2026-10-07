import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../button/glass_button_metrics_scope.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../group/glass_group.dart';
import '../group/glass_union_scope.dart';
import 'glass_back_button.dart';
import 'nav_bar_metrics.dart';

/// The bar row shared by both navigation bars: leading item, centred
/// title, trailing actions merged into one glass capsule. No safe area.
class NavBarContent extends StatelessWidget {
  /// Creates the row.
  const NavBarContent({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
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

  /// The inline title's opacity.
  final double titleOpacity;

  /// When set, opacity changes animate over this long.
  final Duration? titleFade;

  /// Trailing items, merged into one capsule.
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

  @override
  Widget build(BuildContext context) {
    final lead =
        leading ??
        (automaticallyImplyLeading && glassCanImplyBack(context)
            ? GlassBackButton(mode: mode)
            : null);
    final label = CupertinoDynamicColor.resolve(GlassColors.label, context);
    // Bar items keep their size at any text size, as on iOS (the bar's
    // height is fixed); the title still scales.
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
                : Center(widthFactor: 1, child: item(lead)),
            middle: title == null
                ? null
                : _fade(
                    Semantics(
                      header: true,
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontSize: NavBarMetrics.titleFontSize,
                          fontWeight: FontWeight.w600,
                          color: label,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: title!,
                      ),
                    ),
                  ),
            trailing: actions.isEmpty
                ? null
                : GlassGroup(
                    mode: mode,
                    child: GlassUnionScope(
                      id: _actionsUnion,
                      child: item(
                        Row(mainAxisSize: MainAxisSize.min, children: actions),
                      ),
                    ),
                  ),
            middleSpacing: 8,
          ),
        ),
      ),
    );
  }
}
