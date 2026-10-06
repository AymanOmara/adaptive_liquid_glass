import 'package:flutter/material.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import 'nav_bar_content.dart';
import 'nav_bar_metrics.dart';
import 'scroll_edge.dart';

/// iOS 26's navigation bar with an inline title: no bar background, a glass
/// back button when the route can pop, a centred title and the actions
/// merged into one glass capsule. Use it as `Scaffold.appBar` with
/// `extendBodyBehindAppBar: true`. An [AppBar] on the Material path.
///
/// ```dart
/// Scaffold(
///   extendBodyBehindAppBar: true,
///   appBar: GlassNavigationBar(
///     title: const Text('Detail'),
///     actions: [
///       GlassButton.icon(
///         onPressed: share,
///         icon: CupertinoIcons.share,
///         semanticLabel: 'Share',
///       ),
///     ],
///   ),
///   body: content,
/// )
/// ```
class GlassNavigationBar extends StatefulWidget implements PreferredSizeWidget {
  /// Creates a navigation bar.
  const GlassNavigationBar({
    super.key,
    this.title,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.actions = const [],
    this.mode,
  });

  /// The centred title.
  final Widget? title;

  /// Defaults to a `GlassBackButton` when the route can pop.
  final Widget? leading;

  /// Whether to add the default back button.
  final bool automaticallyImplyLeading;

  /// Trailing items, usually `GlassButton.icon`s; merged into one capsule.
  final List<Widget> actions;

  /// Rendering mode; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Size get preferredSize => const Size.fromHeight(NavBarMetrics.barHeight);

  @override
  State<GlassNavigationBar> createState() => _GlassNavigationBarState();
}

class _GlassNavigationBarState extends State<GlassNavigationBar> {
  ScrollNotificationObserverState? _observer;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context);
    _observer?.addListener(_onScroll);
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll(ScrollNotification n) {
    if (n is! ScrollUpdateNotification || n.depth != 0) return;
    if (n.metrics.axis != Axis.vertical) return;
    final under = n.metrics.extentBefore > 0;
    if (under != _scrolledUnder) setState(() => _scrolledUnder = under);
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) {
      if (effective == EffectiveGlassMode.material) {
        return AppBar(
          title: widget.title,
          leading: widget.leading,
          automaticallyImplyLeading: widget.automaticallyImplyLeading,
          actions: widget.actions,
        );
      }
      final top = MediaQuery.paddingOf(context).top;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: GlassScrollEdge(
              visible: _scrolledUnder,
              height: top + NavBarMetrics.barHeight + 16,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: top),
            child: NavBarContent(
              leading: widget.leading,
              automaticallyImplyLeading: widget.automaticallyImplyLeading,
              title: widget.title,
              actions: widget.actions,
              mode: widget.mode,
            ),
          ),
        ],
      );
    },
  );
}
