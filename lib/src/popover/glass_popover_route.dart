import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../core/ios_page_text.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import 'glass_popover_layout.dart';
import 'popover_metrics.dart';

/// The route [showGlassPopover] pushes: a glass bubble over its anchor;
/// a tap outside closes it.
class GlassPopoverRoute<T> extends PopupRoute<T> {
  /// Creates the route.
  GlassPopoverRoute({
    required this.anchor,
    required this.builder,
    this.overlap = PopoverMetrics.overlap,
    this.mode,
    this.capturedThemes,
    this.barrierLabel,
    this.semanticLabel,
  });

  /// How far below the anchor's top the bubble starts.
  final double overlap;

  /// The anchor's rectangle in global coordinates.
  final Rect anchor;

  /// Builds the popover's content.
  final WidgetBuilder builder;

  /// The rendering path.
  final GlassRenderMode? mode;

  /// Themes captured from the presenting context, wrapped around the page
  /// so it draws in the caller's appearance; null uses the navigator's.
  final CapturedThemes? capturedThemes;

  @override
  final String? barrierLabel;

  /// What assistive tech reads for the popover; it names the route.
  final String? semanticLabel;

  @override
  bool get barrierDismissible => true;

  /// SwiftUI leaves the page undimmed behind a popover.
  @override
  Color get barrierColor => GlassColors.transparent;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final page = iosPageText(
      CustomSingleChildLayout(
        delegate: GlassPopoverLayout(
          anchor: anchor,
          padding: MediaQuery.paddingOf(context),
          overlap: overlap,
        ),
        // Its own route scope, so screen readers start inside it.
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: semanticLabel != null ? true : null,
          label: semanticLabel,
          child: GlassGroup(
            mode: mode,
            child: LiquidGlass(
              mode: mode,
              shape: const GlassShape.rect(PopoverMetrics.cornerRadius),
              // SwiftUI's popover text is the plain label colour.
              adaptiveForeground: false,
              padding: const EdgeInsets.symmetric(
                vertical: PopoverMetrics.verticalInset,
              ),
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    );
    return capturedThemes?.wrap(page) ?? page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(
        scale: Tween(begin: 0.6, end: 1.0).animate(curve),
        alignment: Alignment.topCenter,
        child: child,
      ),
    );
  }
}
