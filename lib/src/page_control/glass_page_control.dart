import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/effective_glass_mode.dart';
import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../liquid_glass.dart';
import 'page_control_metrics.dart';

/// iOS 26's page control (UIKit's `UIPageControl`): page dots on a glass
/// capsule.
///
/// ```dart
/// GlassPageControl(
///   count: 3,
///   controller: pageController,
///   onPageChanged: (page) => debugPrint('page $page'),
/// )
/// ```
///
/// Tapping a half steps a page and dragging scrubs the dots, like
/// UIKit's interactive page control. With a [PageController] the control
/// follows the scroll and drives it back on tap. Estimated from UIKit on
/// iOS 26. On the Material path it is a row of Material 3 dots.
class GlassPageControl extends StatefulWidget {
  /// Creates a page control.
  const GlassPageControl({
    super.key,
    required this.count,
    this.currentPage,
    this.controller,
    this.onPageChanged,
    this.glass,
    this.semanticLabel,
    this.mode,
  }) : assert(count >= 1),
       assert(
         currentPage != null || controller != null,
         'Pass currentPage or controller.',
       );

  /// How many pages the dots describe.
  final int count;

  /// The page shown; required unless [controller] is set.
  final int? currentPage;

  /// Reads the page from it and moves it when the user picks one.
  final PageController? controller;

  /// Called with the page the user picks.
  final ValueChanged<int>? onPageChanged;

  /// The capsule's glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// What assistive tech reads for the control.
  final String? semanticLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassPageControl> createState() => _GlassPageControlState();
}

class _GlassPageControlState extends State<GlassPageControl> {
  /// The last rounded page heard from the controller.
  int? _lastControllerPage;

  /// The page picked while the controller is still animating to it, so a
  /// scrub or a second tap counts from there, not from the lagging page.
  int? _pending;

  bool get _interactive =>
      widget.onPageChanged != null || widget.controller != null;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_controllerChanged);
  }

  @override
  void didUpdateWidget(GlassPageControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_controllerChanged);
      _lastControllerPage = null;
      _pending = null;
      widget.controller?.addListener(_controllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_controllerChanged);
    super.dispose();
  }

  /// The controller's rounded page, or null before its first layout.
  int? get _controllerPage {
    final controller = widget.controller;
    if (controller == null || !controller.hasClients) return null;
    return controller.page?.round().clamp(0, widget.count - 1);
  }

  void _controllerChanged() {
    final page = _controllerPage;
    if (page == null) return;
    final controller = widget.controller!;
    // Settled (not mid-animation or drag): the pending pick is done.
    final settled = controller.page == controller.page!.roundToDouble();
    if (_pending != null && (page == _pending || settled)) _pending = null;
    if (page != _lastControllerPage) {
      setState(() => _lastControllerPage = page);
    }
  }

  int get _current =>
      _pending ??
      _controllerPage ??
      widget.currentPage?.clamp(0, widget.count - 1) ??
      0;

  void _pick(int page) {
    final next = page.clamp(0, widget.count - 1);
    if (next == _current) return;
    HapticFeedback.selectionClick();
    widget.onPageChanged?.call(next);
    final controller = widget.controller;
    if (controller != null && controller.hasClients) {
      setState(() => _pending = next);
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduceMotion) {
        controller.jumpToPage(next);
      } else {
        controller.animateToPage(
          next,
          duration: PageControlMetrics.pageAnimation,
          curve: Curves.easeInOut,
        );
      }
    }
  }

  /// A tap in the start half goes back a page, the end half forward.
  void _tap(TapUpDetails details, int current) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final startHalf = rtl
        ? details.localPosition.dx > box.size.width / 2
        : details.localPosition.dx < box.size.width / 2;
    _pick(startHalf ? current - 1 : current + 1);
  }

  /// A drag picks the dot under the finger.
  void _scrub(double dx) {
    final stride = PageControlMetrics.dotSize + PageControlMetrics.dotSpacing;
    final index = ((dx - PageControlMetrics.horizontalPadding) / stride)
        .floor()
        .clamp(0, widget.count - 1);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    _pick(rtl ? widget.count - 1 - index : index);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return GlassModeBuilder(
      mode: widget.mode,
      builder: (context, effective) => Semantics(
        container: true,
        label: widget.semanticLabel ?? 'Page',
        value: '${current + 1} of ${widget.count}',
        increasedValue: current < widget.count - 1
            ? '${current + 2} of ${widget.count}'
            : null,
        decreasedValue: current > 0 ? '$current of ${widget.count}' : null,
        onIncrease: _interactive && current < widget.count - 1
            ? () => _pick(current + 1)
            : null,
        onDecrease: _interactive && current > 0
            ? () => _pick(current - 1)
            : null,
        child: ExcludeSemantics(
          child: effective == EffectiveGlassMode.material
              ? _material(context, current)
              : _glass(context, current),
        ),
      ),
    );
  }

  Widget _glass(BuildContext context, int current) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final control = SizedBox(
      height: PageControlMetrics.height,
      child: LiquidGlass(
        glass: widget.glass,
        mode: widget.mode,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: PageControlMetrics.horizontalPadding,
          ),
          child: Builder(
            builder: (context) {
              final colour =
                  IconTheme.of(context).color ??
                  CupertinoDynamicColor.resolve(GlassColors.label, context);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.count; i++) ...[
                    if (i > 0)
                      const SizedBox(width: PageControlMetrics.dotSpacing),
                    AnimatedOpacity(
                      opacity: i == current
                          ? 1
                          : PageControlMetrics.inactiveOpacity,
                      duration: reduceMotion
                          ? Duration.zero
                          : PageControlMetrics.dotAnimation,
                      child: SizedBox.square(
                        dimension: PageControlMetrics.dotSize,
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            shape: const CircleBorder(),
                            color: colour,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
    if (!_interactive) return control;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => _tap(details, current),
      onHorizontalDragStart: (details) => _scrub(details.localPosition.dx),
      onHorizontalDragUpdate: (details) => _scrub(details.localPosition.dx),
      child: control,
    );
  }

  Widget _material(BuildContext context, int current) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < widget.count; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _interactive ? () => _pick(i) : null,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: PageControlMetrics.materialSpacing / 2,
              ),
              child: AnimatedContainer(
                duration: reduceMotion
                    ? Duration.zero
                    : PageControlMetrics.dotAnimation,
                width: i == current
                    ? PageControlMetrics.materialActiveWidth
                    : PageControlMetrics.materialDotSize,
                height: PageControlMetrics.materialDotSize,
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: i == current
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(
                          alpha: PageControlMetrics.materialInactiveOpacity,
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
