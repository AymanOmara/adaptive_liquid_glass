import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import 'glass_page_control.dart';
import 'page_control_metrics.dart';

/// When a [GlassPageView] shows its page dots; SwiftUI's
/// `PageTabViewStyle.IndexDisplayMode`.
enum GlassPageIndexDisplayMode {
  /// Shown with two or more pages, as SwiftUI's `.automatic`.
  automatic,

  /// Always shown, even for a single page.
  always,

  /// Never shown.
  never,
}

/// SwiftUI's `TabView` with `.tabViewStyle(.page)` (iOS 26): pages swiped
/// sideways over a [GlassPageControl] that follows them.
///
/// ```dart
/// GlassPageView(
///   onPageChanged: (page) => debugPrint('page $page'),
///   children: const [Welcome(), Features(), GetStarted()],
/// )
/// ```
///
/// Swiping moves the dots with the pages; tapping a half of the dots or
/// scrubbing them moves the pages back. The dots float centred above the
/// bottom safe area, as SwiftUI places its index. [indexDisplayMode]
/// hides them (or shows them for one page); [controller] reads or drives
/// the page. Pages follow the reading direction: in right-to-left text the
/// first page is on the right and the next one swipes in from the left.
/// On the Material path the dots are Material 3's.
class GlassPageView extends StatefulWidget {
  /// Pages from a list.
  const GlassPageView({
    super.key,
    required List<Widget> this.children,
    this.controller,
    this.onPageChanged,
    this.indexDisplayMode = GlassPageIndexDisplayMode.automatic,
    this.indexBottom,
    this.glass,
    this.semanticLabel,
    this.physics,
    this.mode,
  }) : itemCount = null,
       itemBuilder = null;

  /// [itemCount] pages built on demand.
  const GlassPageView.builder({
    super.key,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.controller,
    this.onPageChanged,
    this.indexDisplayMode = GlassPageIndexDisplayMode.automatic,
    this.indexBottom,
    this.glass,
    this.semanticLabel,
    this.physics,
    this.mode,
  }) : assert(itemCount >= 0),
       children = null;

  /// The pages, for the default constructor.
  final List<Widget>? children;

  /// How many pages, for [GlassPageView.builder].
  final int? itemCount;

  /// Builds a page, for [GlassPageView.builder].
  final IndexedWidgetBuilder? itemBuilder;

  /// Reads or moves the page; one is made when null.
  final PageController? controller;

  /// Called with the page settled on, by a swipe or the dots.
  final ValueChanged<int>? onPageChanged;

  /// When the dots show.
  final GlassPageIndexDisplayMode indexDisplayMode;

  /// The dots' bottom edge above the bottom safe area; iOS 26's by
  /// default.
  final double? indexBottom;

  /// The dots' capsule glass.
  final Glass? glass;

  /// What assistive tech reads for the dots.
  final String? semanticLabel;

  /// The page view's scroll physics.
  final ScrollPhysics? physics;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  int get _count => children?.length ?? itemCount!;

  @override
  State<GlassPageView> createState() => _GlassPageViewState();
}

class _GlassPageViewState extends State<GlassPageView> {
  PageController? _own;

  PageController get _controller =>
      widget.controller ?? (_own ??= PageController());

  @override
  void didUpdateWidget(GlassPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _own != null) {
      _own!.dispose();
      _own = null;
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget._count;
    final pages = widget.children != null
        ? PageView(
            controller: _controller,
            physics: widget.physics,
            onPageChanged: widget.onPageChanged,
            children: widget.children!,
          )
        : PageView.builder(
            controller: _controller,
            physics: widget.physics,
            onPageChanged: widget.onPageChanged,
            itemCount: count,
            itemBuilder: widget.itemBuilder!,
          );
    final dots = switch (widget.indexDisplayMode) {
      GlassPageIndexDisplayMode.never => false,
      GlassPageIndexDisplayMode.always => count >= 1,
      GlassPageIndexDisplayMode.automatic => count >= 2,
    };
    // One tree shape either way, so toggling the dots keeps the pages.
    return Stack(
      fit: StackFit.expand,
      children: [
        pages,
        if (dots)
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom:
                MediaQuery.paddingOf(context).bottom +
                (widget.indexBottom ?? PageControlMetrics.pageViewBottom),
            child: Center(
              // The page view reports settled pages; the dots only drive it.
              child: GlassPageControl(
                count: count,
                controller: _controller,
                glass: widget.glass,
                semanticLabel: widget.semanticLabel,
                mode: widget.mode,
              ),
            ),
          ),
      ],
    );
  }
}
