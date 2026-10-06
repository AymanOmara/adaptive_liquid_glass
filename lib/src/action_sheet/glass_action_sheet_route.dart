import 'package:flutter/cupertino.dart';

import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_page_text.dart';
import '../dialog/glass_dialog_action.dart';
import 'action_sheet_metrics.dart';
import 'glass_action_sheet_card.dart';

/// Internal. The modal route of [showGlassActionSheet]: the card at the
/// bottom of the dimmed screen, sliding up.
class GlassActionSheetRoute extends PopupRoute<GlassDialogAction> {
  /// Creates the route.
  GlassActionSheetRoute({
    required this.actions,
    this.title,
    this.message,
    this.cancel,
    this.mode,
    this.capturedThemes,
    this.barrierLabel,
  });

  /// See [GlassActionSheetCard.title].
  final String? title;

  /// See [GlassActionSheetCard.message].
  final String? message;

  /// See [GlassActionSheetCard.actions].
  final List<GlassDialogAction> actions;

  /// See [GlassActionSheetCard.cancel].
  final GlassDialogAction? cancel;

  /// The rendering path.
  final GlassRenderMode? mode;

  /// Themes captured from the presenting context, wrapped around the page
  /// so it draws in the caller's appearance; null uses the navigator's.
  final CapturedThemes? capturedThemes;

  @override
  final String? barrierLabel;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => GlassColors.sheetBarrier;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final page = iosPageText(
      SafeArea(
        minimum: const EdgeInsets.all(ActionSheetMetrics.margin),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ActionSheetMetrics.maxWidth,
            ),
            child: GlassActionSheetCard(
              title: title,
              message: message,
              actions: actions,
              cancel: cancel,
              mode: mode,
              onAction: (a) => Navigator.of(context).pop(a),
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
    // Reduce Motion: fade instead of sliding up from below.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return FadeTransition(opacity: animation, child: child);
    }
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      ),
      child: child,
    );
  }
}
