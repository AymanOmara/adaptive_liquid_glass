import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show MaterialLocalizations;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../button/glass_button.dart';
import '../button/glass_button_shape.dart';
import '../core/glass_colors.dart';
import '../core/ios_page_text.dart';
import 'full_screen_cover_drag.dart';
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
    this.dragToDismiss = false,
    this.showsCloseButton = false,
    this.closeButtonSemanticLabel,
    super.settings,
  });

  /// Whether dragging the cover down dismisses it, like a sheet.
  final bool dragToDismiss;

  /// Whether a glass close button (an xmark circle) sits top-trailing.
  final bool showsCloseButton;

  /// What assistive tech calls the close button; defaults to the
  /// localized "Close".
  final String? closeButtonSemanticLabel;

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
      backgroundColor ?? GlassColors.fullScreenCoverBackground,
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
              child: iosPageText(
                showsCloseButton
                    ? Stack(
                        children: [
                          // Fills the safe area so the button sits at its
                          // corner however small the content is.
                          const SizedBox.expand(),
                          Builder(builder: builder),
                          PositionedDirectional(
                            top: 0,
                            end: FullScreenCoverMetrics.closeButtonInset,
                            child: Builder(builder: _closeButton),
                          ),
                        ],
                      )
                    : Builder(builder: builder),
              ),
            ),
          ),
        ),
      ),
    );
    final draggable = FullScreenCoverDragDismiss(
      enabled: dragToDismiss,
      child: page,
    );
    return capturedThemes?.wrap(draggable) ?? draggable;
  }

  /// iOS 26's close button: a glass circle with an xmark, popping the
  /// cover (respecting `PopScope`).
  Widget _closeButton(BuildContext context) => GlassButton.icon(
    onPressed: () => Navigator.maybePop(context),
    icon: CupertinoIcons.xmark,
    shape: GlassButtonShape.circle,
    semanticLabel:
        closeButtonSemanticLabel ??
        Localizations.of<MaterialLocalizations>(
          context,
          MaterialLocalizations,
        )?.closeButtonLabel ??
        'Close',
  );

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
