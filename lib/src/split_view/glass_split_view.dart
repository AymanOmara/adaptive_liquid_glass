import 'package:flutter/material.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../liquid_glass.dart';
import '../tab_bar/tab_sidebar_metrics.dart';
import 'glass_split_view_column.dart';
import 'glass_split_view_controller.dart';

/// iOS's `NavigationSplitView`: a [sidebar], an optional [content] column
/// and a [detail] that sit side by side on a wide screen and collapse to
/// one pushed-over-the-other stack on a compact one.
///
/// ```dart
/// GlassSplitView(
///   sidebar: Builder(
///     builder: (context) => ListView(children: [
///       GlassListTile(
///         title: const Text('Inbox'),
///         onTap: () => GlassSplitView.of(context)
///             .showColumn(GlassSplitViewColumn.detail),
///       ),
///     ]),
///   ),
///   detail: const InboxDetail(),
/// )
/// ```
///
/// At [regularWidth] and wider the sidebar is a floating glass panel, as
/// in the sidebar of `GlassTabBarStyle.sidebarAdaptable`, with the page
/// beside it; narrower, only the column the controller's
/// [GlassSplitViewController.compactColumn] names shows, and changing it
/// slides the next column in as a push. On Android's back button a compact
/// view steps back a column before the route pops.
///
/// On the Material path the sidebar is a flat surface column with a
/// divider. Each column should bring its own bars (a `GlassScaffold`, say);
/// the view only lays them out. Column resizing and the `balanced` /
/// `prominentDetail` styles are not built.
class GlassSplitView extends StatefulWidget {
  /// Creates a two-column view, or three with a [content] column.
  const GlassSplitView({
    super.key,
    required this.sidebar,
    required this.detail,
    this.content,
    this.controller,
    this.sidebarWidth = TabSidebarMetrics.sidebarWidth,
    this.contentWidth = 320,
    this.regularWidth = TabSidebarMetrics.regularWidth,
    this.mode,
  });

  /// The leading column, usually a list.
  final Widget sidebar;

  /// The middle column; null makes a two-column view.
  final Widget? content;

  /// The last column.
  final Widget detail;

  /// Drives and reports the shown columns; the view makes its own when null.
  final GlassSplitViewController? controller;

  /// The sidebar panel's width.
  final double sidebarWidth;

  /// The content column's width.
  final double contentWidth;

  /// The width from which the columns sit side by side.
  final double regularWidth;

  /// Rendering mode of the sidebar's glass; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The controller of the nearest [GlassSplitView] above [context].
  static GlassSplitViewController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_SplitScope>()
        ?.notifier;
    assert(scope != null, 'No GlassSplitView above this context.');
    return scope!;
  }

  /// Like [of], or null outside a [GlassSplitView].
  static GlassSplitViewController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SplitScope>()?.notifier;

  @override
  State<GlassSplitView> createState() => _GlassSplitViewState();
}

class _SplitScope extends InheritedNotifier<GlassSplitViewController> {
  const _SplitScope({
    required GlassSplitViewController super.notifier,
    required super.child,
  });
}

const _curve = Curves.easeOutCubic;

class _GlassSplitViewState extends State<GlassSplitView> {
  GlassSplitViewController? _own;

  GlassSplitViewController get _controller =>
      widget.controller ?? (_own ??= GlassSplitViewController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  List<GlassSplitViewColumn> get _columns => [
    GlassSplitViewColumn.sidebar,
    if (widget.content != null) GlassSplitViewColumn.content,
    GlassSplitViewColumn.detail,
  ];

  Widget _column(GlassSplitViewColumn c) => switch (c) {
    GlassSplitViewColumn.sidebar => widget.sidebar,
    GlassSplitViewColumn.content => widget.content!,
    GlassSplitViewColumn.detail => widget.detail,
  };

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return _SplitScope(
      notifier: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => GlassModeBuilder(
          mode: widget.mode,
          builder: (context, effective) {
            final material = effective == EffectiveGlassMode.material;
            return LayoutBuilder(
              builder: (context, box) => box.maxWidth >= widget.regularWidth
                  ? _wide(context, controller, material)
                  : _compact(context, controller),
            );
          },
        ),
      ),
    );
  }

  // --- regular width ------------------------------------------------

  Widget _wide(
    BuildContext context,
    GlassSplitViewController controller,
    bool material,
  ) {
    final threeColumn = widget.content != null;
    final v = controller.visibility;
    final showSidebar = switch (v) {
      GlassSplitViewVisibility.automatic ||
      GlassSplitViewVisibility.all => true,
      GlassSplitViewVisibility.doubleColumn => !threeColumn,
      GlassSplitViewVisibility.detailOnly => false,
    };
    final showContent = threeColumn && v != GlassSplitViewVisibility.detailOnly;
    final inset = material ? 0.0 : TabSidebarMetrics.sidebarInset;
    final sidebarSlot = widget.sidebarWidth + (material ? 0 : 2 * inset);
    return Row(
      children: [
        _Slot(
          visible: showSidebar,
          width: sidebarSlot,
          child: _sidebarPanel(context, material, inset),
        ),
        if (threeColumn)
          _Slot(
            visible: showContent,
            width: widget.contentWidth,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: BorderDirectional(
                  end: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: widget.content,
            ),
          ),
        Expanded(child: widget.detail),
      ],
    );
  }

  Widget _sidebarPanel(BuildContext context, bool material, double inset) {
    if (material) {
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: BorderDirectional(
              end: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: widget.sidebar,
        ),
      );
    }
    final pad = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(
        top: pad.top + inset,
        bottom: pad.bottom + inset,
        left: inset,
        right: inset,
      ),
      child: LayoutBuilder(
        builder: (context, box) => LiquidGlass(
          mode: widget.mode,
          shape: const GlassShape.rect(TabSidebarMetrics.sidebarRadius),
          child: SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                TabSidebarMetrics.sidebarRadius,
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeBottom: true,
                child: widget.sidebar,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- compact width ------------------------------------------------

  Widget _compact(BuildContext context, GlassSplitViewController controller) {
    final columns = _columns;
    final target = columns.contains(controller.compactColumn)
        ? columns.indexOf(controller.compactColumn)
        : columns.length - 1;
    return PopScope(
      canPop: target == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && target > 0) {
          controller.compactColumn = columns[target - 1];
        }
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: target.toDouble()),
        duration: TabSidebarMetrics.duration,
        curve: _curve,
        builder: (context, pos, _) => LayoutBuilder(
          builder: (context, box) {
            final sign = Directionality.of(context) == TextDirection.rtl
                ? -1
                : 1;
            return ClipRect(
              child: Stack(
                children: [
                  for (var i = 0; i < columns.length; i++)
                    if ((i - pos).abs() < 1 || i == target)
                      Positioned.fill(
                        left: _shift(i - pos, box.maxWidth) * sign,
                        right: -_shift(i - pos, box.maxWidth) * sign,
                        child: _compactPage(columns[i], i - pos),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // A pushed column slides over the one behind it, which drifts a third
  // of the way out, as UINavigationController does.
  double _shift(double d, double width) => d >= 0 ? d * width : d * width / 3;

  Widget _compactPage(GlassSplitViewColumn c, double d) {
    final page = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: d < 0 ? 0.1 * -d : 0),
      ),
      child: _column(c),
    );
    return KeyedSubtree(key: ValueKey(c), child: page);
  }
}

/// A column slot that animates its width to zero and keeps the column's
/// state while hidden.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.visible,
    required this.width,
    required this.child,
  });

  final bool visible;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: visible ? 1 : 0),
    duration: TabSidebarMetrics.duration,
    curve: _curve,
    builder: (context, t, child) => ClipRect(
      child: SizedBox(
        width: width * t,
        child: OverflowBox(
          alignment: AlignmentDirectional.centerEnd,
          minWidth: width,
          maxWidth: width,
          child: t == 0 ? Offstage(child: child) : child,
        ),
      ),
    ),
    child: child,
  );
}
