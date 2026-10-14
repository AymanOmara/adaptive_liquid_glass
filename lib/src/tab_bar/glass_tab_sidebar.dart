import 'package:flutter/cupertino.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_shape.dart';
import '../core/liquid_glass_theme.dart';
import '../core/render_mode_resolver.dart';
import '../liquid_glass.dart';
import '../platform/glass_platform.dart';
import '../symbol/glass_symbol.dart';
import 'bar_shadow.dart';
import 'glass_tab_bar.dart';
import 'glass_tab_bar_item.dart';
import 'tab_lens.dart';
import 'tab_sidebar_metrics.dart';

/// [tabBar]'s regular-width form under `.sidebarAdaptable`: a floating bar
/// of text tabs at the top with a sidebar button, and the sidebar itself,
/// over [child] (the page).
class GlassTabSidebar extends StatefulWidget {
  /// Lays [tabBar] out as iOS 26.4's iPad tab bar over [child].
  const GlassTabSidebar({super.key, required this.tabBar, required this.child});

  /// The tabs, selection and callbacks.
  final GlassTabBar tabBar;

  /// The page under the bar.
  final Widget child;

  @override
  State<GlassTabSidebar> createState() => _GlassTabSidebarState();
}

class _GlassTabSidebarState extends State<GlassTabSidebar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _open;

  // Created here, not lazily: one first read in dispose would create
  // its ticker on a deactivated element.
  @override
  void initState() {
    super.initState();
    _open = AnimationController(
      vsync: this,
      duration: TabSidebarMetrics.duration,
    );
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _toggle() =>
      _open.isForwardOrCompleted ? _open.reverse() : _open.forward();

  void _select(int index) {
    widget.tabBar.onSelected(index);
    _open.reverse();
  }

  Color _selected(BuildContext context) => CupertinoDynamicColor.resolve(
    widget.tabBar.tint ?? GlassColors.tabBarSelected,
    context,
  );

  Color _ink(BuildContext context) =>
      CupertinoDynamicColor.resolve(GlassColors.label, context);

  Widget _toggleButton(BuildContext context, String label) => Semantics(
    button: true,
    label: label,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: SizedBox.square(
        dimension: TabSidebarMetrics.topBarHeight,
        child: Center(
          child: IconTheme(
            data: IconThemeData(
              color: _ink(context),
              size: TabSidebarMetrics.toggleSize,
            ),
            child: const GlassSymbol(
              'sidebar.left',
              fallback: CupertinoIcons.sidebar_left,
              pointSize: 17,
            ),
          ),
        ),
      ),
    ),
  );

  Widget _topBar(BuildContext context) {
    final bar = widget.tabBar;
    final style = TextStyle(
      fontSize: TabSidebarMetrics.labelSize,
      color: _ink(context),
      fontWeight: FontWeight.w500,
      letterSpacing: -0.4,
    );
    return LiquidGlass(
      glass: bar.glass,
      mode: bar.mode,
      child: SizedBox(
        height: TabSidebarMetrics.topBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TabSidebarMetrics.topBarInset,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: TabSidebarMetrics.toggleSlot,
                child: _toggleButton(context, 'Show Sidebar'),
              ),
              for (var i = 0; i < bar.items.length; i++)
                if (!bar.items[i].isSpacer)
                  _topTab(context, bar.items[i], i, style),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topTab(
    BuildContext context,
    GlassTabBarItem item,
    int index,
    TextStyle style,
  ) {
    final selected = index == widget.tabBar.selectedIndex;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.tabBar.onSelected(index),
        child: Container(
          height:
              TabSidebarMetrics.topBarHeight -
              2 * TabSidebarMetrics.topBarInset,
          padding: const EdgeInsets.symmetric(
            horizontal: TabSidebarMetrics.tabPadding,
          ),
          alignment: Alignment.center,
          decoration: selected
              ? ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: GlassColors.black.withValues(
                    alpha: TabSidebarMetrics.pillFill,
                  ),
                )
              : null,
          child: Text(
            item.label,
            style: selected
                ? style.copyWith(
                    color: _selected(context),
                    fontWeight: FontWeight.w600,
                  )
                : style,
          ),
        ),
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    final bar = widget.tabBar;
    final style = TextStyle(
      fontSize: TabSidebarMetrics.labelSize,
      color: _ink(context),
      letterSpacing: -0.4,
    );
    return LiquidGlass(
      glass: bar.glass,
      mode: bar.mode,
      shape: const GlassShape.rect(TabSidebarMetrics.sidebarRadius),
      child: SizedBox(
        width: TabSidebarMetrics.sidebarWidth,
        child: Stack(
          children: [
            PositionedDirectional(
              top:
                  TabSidebarMetrics.sidebarToggleTop -
                  TabSidebarMetrics.topBarHeight / 2,
              end:
                  TabSidebarMetrics.sidebarToggleEnd -
                  TabSidebarMetrics.topBarHeight / 2,
              child: _toggleButton(context, 'Hide Sidebar'),
            ),
            for (var i = 0; i < bar.items.length; i++)
              if (!bar.items[i].isSpacer)
                PositionedDirectional(
                  top:
                      TabSidebarMetrics.rowsTop +
                      i * TabSidebarMetrics.rowHeight,
                  start: TabSidebarMetrics.rowInset,
                  end: TabSidebarMetrics.rowInset,
                  height: TabSidebarMetrics.rowHeight,
                  child: _row(context, bar.items[i], i, style),
                ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    GlassTabBarItem item,
    int index,
    TextStyle style,
  ) {
    final selected = index == widget.tabBar.selectedIndex;
    final color = selected ? _selected(context) : _ink(context);
    const iconCentre =
        TabSidebarMetrics.rowIconCentre - TabSidebarMetrics.rowInset;
    const iconSize = TabSidebarMetrics.rowIconSize;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(index),
        child: DecoratedBox(
          decoration: selected
              ? ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: GlassColors.black.withValues(
                    alpha: TabSidebarMetrics.rowFill,
                  ),
                )
              : const BoxDecoration(),
          child: Stack(
            children: [
              PositionedDirectional(
                start: iconCentre - iconSize,
                width: iconSize * 2,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: color, size: iconSize),
                    child: item.iconFor(selected: selected),
                  ),
                ),
              ),
              PositionedDirectional(
                start:
                    TabSidebarMetrics.rowLabelStart -
                    TabSidebarMetrics.rowInset,
                top: 0,
                bottom: 0,
                end: 0,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(item.label, style: style.copyWith(color: color)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Shader glass draws no shadow of its own; the bar's capsule shadow is
  // painted under it.
  Widget _glass(BuildContext context, Widget child) {
    final shader =
        resolveGlassMode(
          requested:
              widget.tabBar.mode ?? LiquidGlassTheme.of(context).defaultMode,
          environment: GlassPlatform.instance.environment.value,
          highContrast: MediaQuery.highContrastOf(context),
        ) ==
        EffectiveGlassMode.shader;
    return CustomPaint(
      painter: shader ? const BarShadow() : null,
      child: withTabBarGlass(context, child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        Positioned(
          top: top + TabSidebarMetrics.topBarTop,
          left: 0,
          right: 0,
          // The open sidebar takes the bar's place.
          child: AnimatedBuilder(
            animation: _open,
            builder: (context, child) => Opacity(
              opacity: 1 - _open.value,
              child: IgnorePointer(ignoring: _open.value > 0, child: child),
            ),
            child: Center(child: _glass(context, _topBar(context))),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _open,
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(_open.value);
              if (t == 0) return const SizedBox.shrink();
              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _open.reverse,
                      child: ColoredBox(
                        color: GlassColors.black.withValues(
                          alpha: TabSidebarMetrics.dim * t,
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    top: top + TabSidebarMetrics.sidebarInset,
                    bottom: TabSidebarMetrics.sidebarInset,
                    start:
                        TabSidebarMetrics.sidebarInset -
                        (1 - t) *
                            (TabSidebarMetrics.sidebarWidth +
                                TabSidebarMetrics.sidebarInset),
                    child: withTabBarGlass(context, _sidebar(context)),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
