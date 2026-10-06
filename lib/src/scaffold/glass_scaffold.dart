import 'package:flutter/material.dart';

import '../core/glass_render_mode.dart';
import '../core/theme.dart';
import '../foreground/glass_backdrop_source.dart';
import '../platform/glass_platform.dart';
import '../tab_bar/glass_tab_bar.dart';
import '../tab_bar/tab_bar_fill_scope.dart';
import '../toolbar/toolbar_metrics.dart';
import 'scaffold_metrics.dart';

/// An iOS 26 screen in one widget: content running under a
/// [navigationBar] at the top and a floating [tabBar] or [toolbar] (with an
/// optional [bottomAccessory]) at the bottom.
///
/// ```dart
/// GlassScaffold(
///   navigationBar: const GlassNavigationBar(title: Text('Inbox')),
///   tabBar: GlassTabBar(
///     items: tabs,
///     selectedIndex: tab,
///     onSelected: (i) => setState(() => tab = i),
///   ),
///   body: ListView(children: rows),
/// )
/// ```
///
/// The body fills the screen, so the glass has content to refract, and its
/// [MediaQuery] padding grows by the bars, so scroll views and [SafeArea]s
/// in it keep their content clear of them, as iOS's safe area does. The
/// body is a [GlassBackdropSource] unless [sampleBackdrop] is false.
///
/// On the Material path the same layout holds Material's bars.
class GlassScaffold extends StatelessWidget {
  /// Creates a scaffold.
  const GlassScaffold({
    super.key,
    required this.body,
    this.navigationBar,
    this.tabBar,
    this.toolbar,
    this.bottomAccessory,
    this.backgroundColor,
    this.sampleBackdrop = true,
  }) : assert(
         tabBar == null || toolbar == null,
         'A screen has a tab bar or a toolbar at the bottom, not both.',
       );

  /// The screen's content, drawn behind the bars.
  final Widget body;

  /// The bar at the top, usually a `GlassNavigationBar`.
  final PreferredSizeWidget? navigationBar;

  /// The floating tab bar at the bottom.
  final GlassTabBar? tabBar;

  /// The floating bottom toolbar, usually a `GlassToolbar`, in place of a
  /// [tabBar].
  final PreferredSizeWidget? toolbar;

  /// A bar floating just above [tabBar], usually a [GlassBottomAccessory].
  final PreferredSizeWidget? bottomAccessory;

  /// The page colour. Defaults to the theme's scaffold background.
  final Color? backgroundColor;

  /// Whether glass samples the body to pick readable label colours (see
  /// [GlassBackdropSource]); costs a small GPU readback every 250 ms.
  final bool sampleBackdrop;

  /// The tab bar draws shader glass wherever shaders run (so its lens can
  /// refract it); native glass next to it leaves the shader a band it
  /// cannot sample. The accessory takes the same path, unless the app
  /// chose one for it.
  static Widget _sameGlassAsTabBar(
    BuildContext context,
    GlassTabBar tabBar,
    Widget accessory,
  ) {
    if (!GlassPlatform.instance.environment.value.shaderSupported) {
      return accessory;
    }
    final theme = LiquidGlassTheme.of(context);
    return LiquidGlassTheme(
      data: theme.copyWith(defaultMode: tabBar.mode ?? GlassRenderMode.shader),
      child: accessory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final safeBottom = media.padding.bottom;
    final tabBar = this.tabBar;
    final toolbar = this.toolbar;
    final accessory = bottomAccessory;
    final gap = safeBottom <= 0
        ? ScaffoldMetrics.tabBarBottomFlat
        : toolbar != null
        ? ToolbarMetrics.bottom
        : ScaffoldMetrics.tabBarBottom;
    var bars = 0.0;
    final bottomBar = tabBar != null || toolbar != null;
    if (tabBar != null) bars += tabBar.height;
    if (toolbar != null) bars += toolbar.preferredSize.height;
    if (accessory != null) {
      bars += accessory.preferredSize.height;
      if (bottomBar) bars += ScaffoldMetrics.accessoryGap;
    }
    final bottomInset = bars > 0 ? gap + bars : safeBottom;
    Widget content = body;
    if (sampleBackdrop) {
      // The page colour is part of what glass floats over: without it the
      // sampler reads a transparent body as dark, and labels on glass over
      // a light page turn white.
      content = GlassBackdropSource(
        child: ColoredBox(
          color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
          child: content,
        ),
      );
    }
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: navigationBar,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Builder(
            // Below the Scaffold, so the navigation bar's height is in the
            // top padding already.
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.paddingOf(
                  context,
                ).copyWith(bottom: bottomInset),
              ),
              child: content,
            ),
          ),
          if (bars > 0)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: gap,
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (accessory != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: ScaffoldMetrics.accessoryInset,
                        ),
                        child: tabBar == null
                            ? accessory
                            : _sameGlassAsTabBar(context, tabBar, accessory),
                      ),
                    if (accessory != null && bottomBar)
                      const SizedBox(height: ScaffoldMetrics.accessoryGap),
                    if (tabBar != null)
                      accessory == null && tabBar.onSearch == null
                          ? Center(child: tabBar)
                          : tabBar.onSearch != null
                          // The search tab spreads the bar across.
                          ? Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: ScaffoldMetrics.accessoryInset,
                              ),
                              child: tabBar,
                            )
                          // As iOS 26: with an accessory the tab bar
                          // widens to the accessory's width.
                          : Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: ScaffoldMetrics.accessoryInset,
                              ),
                              child: TabBarFillScope(child: tabBar),
                            ),
                    ?toolbar,
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
