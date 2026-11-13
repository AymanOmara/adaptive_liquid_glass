import 'package:flutter/material.dart';

import '../navigation/glass_scroll_edge.dart';
import '../scaffold/tab_bar_scroll_edge.dart';
import 'render_measure_size.dart';
import 'safe_area_bar_metrics.dart';

/// The edge a [GlassSafeAreaBar] sits on.
enum GlassSafeAreaEdge {
  /// The top edge.
  top,

  /// The bottom edge.
  bottom,

  /// The leading edge: left in left-to-right text, right in right-to-left.
  start,

  /// The trailing edge: right in left-to-right text, left in right-to-left.
  end,
}

/// SwiftUI's `.safeAreaBar(edge:alignment:spacing:content:)` (iOS 26): a
/// bar on any edge of [child] that insets it, with iOS 26's scroll edge
/// effect under the bar.
///
/// ```dart
/// GlassSafeAreaBar(
///   edge: GlassSafeAreaEdge.bottom,
///   bar: Row(children: [
///     GlassButton(onPressed: filter, child: const Text('Filter')),
///     const Spacer(),
///     GlassButton(onPressed: compose, child: const Text('Compose')),
///   ]),
///   child: ListView(children: rows),
/// )
/// ```
///
/// The bar sits inside the safe area on its [edge], at [alignment] along
/// that edge, and the edge's safe-area padding grows by the bar's extent
/// plus [spacing], so scroll views in [child] scroll their content clear
/// of it (as `MediaQuery` padding does for a `Scaffold`'s bars). Stacking
/// several, the outer bar sits nearer the edge, as SwiftUI does.
///
/// The bar paints what it is given, so give it glass (`GlassButton`,
/// `GlassEffect`, a `GlassToolbar`…), as SwiftUI does. Unlike
/// `safeAreaInset`, iOS 26 fades scrolled content into the page under a
/// top or bottom bar ([scrollEdgeEffect]); the fade shows once content is
/// under the bar. `GlassScaffold`'s navigation bar, toolbar and bottom
/// accessory are fixed slots built the same way; this works anywhere.
/// Identical on the Material path, where the bar's own widgets fall back.
class GlassSafeAreaBar extends StatefulWidget {
  /// A [bar] on [edge] of [child].
  const GlassSafeAreaBar({
    super.key,
    required this.edge,
    required this.bar,
    required this.child,
    this.alignment = 0,
    this.spacing = 0,
    this.scrollEdgeEffect = true,
    this.backgroundColor,
  });

  /// Which edge the bar sits on.
  final GlassSafeAreaEdge edge;

  /// The bar's content; as wide as the edge for [GlassSafeAreaEdge.top]
  /// and [GlassSafeAreaEdge.bottom], as tall for the side edges, unless
  /// it sizes itself smaller.
  final Widget bar;

  /// What the bar insets.
  final Widget child;

  /// Where a bar smaller than its edge sits along it, from -1 (start or
  /// top) to 1 (end or bottom); SwiftUI's `alignment`. Centred by default.
  final double alignment;

  /// Extra inset between the bar and [child]'s content; SwiftUI's
  /// `spacing`.
  final double spacing;

  /// Whether scrolled content fades into the page under a top or bottom
  /// bar, as iOS 26 does. Side bars never fade.
  final bool scrollEdgeEffect;

  /// The page colour the scroll edge fades to; the theme's scaffold
  /// background by default.
  final Color? backgroundColor;

  @override
  State<GlassSafeAreaBar> createState() => _GlassSafeAreaBarState();
}

class _GlassSafeAreaBarState extends State<GlassSafeAreaBar> {
  Size _barSize = Size.zero;

  /// Whether content is scrolled under the bar.
  bool _under = false;

  bool get _vertical =>
      widget.edge == GlassSafeAreaEdge.top ||
      widget.edge == GlassSafeAreaEdge.bottom;

  void _measured(Size size) {
    if (size == _barSize) return;
    // Layout reports it; the inset follows on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && size != _barSize) setState(() => _barSize = size);
    });
  }

  bool _onMetrics(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final under = switch (widget.edge) {
      GlassSafeAreaEdge.top => metrics.extentBefore > 0,
      GlassSafeAreaEdge.bottom => metrics.extentAfter > 0,
      _ => false,
    };
    if (under != _under) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && under != _under) setState(() => _under = under);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final padding = media.padding;
    final extent =
        (_vertical ? _barSize.height : _barSize.width) +
        (_barSize == Size.zero ? 0 : widget.spacing);
    // Start and end resolved to physical sides.
    final left =
        (widget.edge == GlassSafeAreaEdge.start && !rtl) ||
        (widget.edge == GlassSafeAreaEdge.end && rtl);
    final right =
        (widget.edge == GlassSafeAreaEdge.end && !rtl) ||
        (widget.edge == GlassSafeAreaEdge.start && rtl);
    final inset = padding.copyWith(
      top: widget.edge == GlassSafeAreaEdge.top ? padding.top + extent : null,
      bottom: widget.edge == GlassSafeAreaEdge.bottom
          ? padding.bottom + extent
          : null,
      left: left ? padding.left + extent : null,
      right: right ? padding.right + extent : null,
    );
    Widget content = MediaQuery(
      data: media.copyWith(padding: inset),
      child: widget.child,
    );
    final fades = widget.scrollEdgeEffect && _vertical;
    if (fades) {
      content = NotificationListener<ScrollNotification>(
        onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
          child: content,
        ),
      );
    }
    final page =
        widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    // The bar keeps the safe area on its own edge (it sits inside it) and
    // loses the padding outer bars added on the others.
    final bar = MediaQuery(
      data: media.removePadding(
        removeTop: widget.edge != GlassSafeAreaEdge.top,
        removeBottom: widget.edge != GlassSafeAreaEdge.bottom,
        removeLeft: !left,
        removeRight: !right,
      ),
      child: MeasureSize(onSize: _measured, child: widget.bar),
    );
    final along = widget.alignment.clamp(-1.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        if (fades && widget.edge == GlassSafeAreaEdge.top)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: GlassScrollEdge(
              visible: _under,
              height:
                  padding.top +
                  _barSize.height +
                  SafeAreaBarMetrics.topEdgeOverhang,
            ),
          ),
        if (fades && widget.edge == GlassSafeAreaEdge.bottom && _under)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TabBarScrollEdge(color: page),
          ),
        switch (widget.edge) {
          GlassSafeAreaEdge.top => Positioned(
            left: padding.left,
            right: padding.right,
            top: padding.top,
            child: Align(alignment: Alignment(along, -1), child: bar),
          ),
          GlassSafeAreaEdge.bottom => Positioned(
            left: padding.left,
            right: padding.right,
            bottom: padding.bottom,
            child: Align(alignment: Alignment(along, 1), child: bar),
          ),
          _ => Positioned(
            top: padding.top,
            bottom: padding.bottom,
            left: left ? padding.left : null,
            right: right ? padding.right : null,
            child: Align(alignment: Alignment(0, along), child: bar),
          ),
        },
      ],
    );
  }
}
