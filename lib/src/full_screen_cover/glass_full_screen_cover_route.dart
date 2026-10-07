import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../core/ios_page_text.dart';
import 'full_screen_cover_metrics.dart';

/// The route [showGlassFullScreenCover] pushes on the glass path: an
/// opaque page sliding up over the whole screen, like SwiftUI's
/// `.fullScreenCover`. Needs no Material.
class GlassFullScreenCoverRoute<T> extends PageRoute<T> {
  /// Creates the route.
  GlassFullScreenCoverRoute({
    required this.builder,
    this.backgroundColor,
    this.semanticLabel,
    this.capturedThemes,
    super.settings,
  });

  /// Builds the cover's content, inside the safe area.
  final WidgetBuilder builder;

  /// The cover's background, edge to edge; defaults to the system
  /// background, opaque like SwiftUI's cover.
  final Color? backgroundColor;

  /// What assistive tech calls the route.
  final String? semanticLabel;

  /// Themes captured from the presenting context, wrapped around the
  /// page so it draws in the caller's appearance; null uses the
  /// navigator's.
  final CapturedThemes? capturedThemes;

  @override
  bool get opaque => true;

  @override
  bool get fullscreenDialog => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => FullScreenCoverMetrics.duration;

  @override
  Duration get reverseTransitionDuration =>
      FullScreenCoverMetrics.reverseDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final background = CupertinoDynamicColor.resolve(
      backgroundColor ?? CupertinoColors.systemBackground,
      context,
    );
    final page = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      label: semanticLabel,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Light background: dark status-bar glyphs, and the reverse.
        value: background.computeLuminance() > 0.5
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: ColoredBox(
          color: background,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            // The background runs edge to edge; the content, like
            // SwiftUI's, still respects the safe area.
            child: SafeArea(
              top: true,
              bottom: true,
              child: iosPageText(Builder(builder: builder)),
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
    // The page below neither scales nor dims; only the cover moves.
    final curved = CurvedAnimation(
      parent: animation,
      curve: FullScreenCoverMetrics.curve,
      reverseCurve: FullScreenCoverMetrics.reverseCurve,
    );
    // iOS cross-fades a cover under Reduce Motion instead of sliding it.
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: curved, child: child);
    }
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}
