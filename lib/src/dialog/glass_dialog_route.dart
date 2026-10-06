import 'package:flutter/cupertino.dart';

import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_page_text.dart';
import 'glass_dialog_action.dart';
import 'glass_dialog_card.dart';

/// The modal route of [showGlassAlert] and [showGlassConfirmationDialog]
/// (and of `showGlassActionSheet`): the card in the middle of the
/// screen, scaling in.
class GlassDialogRoute extends PopupRoute<GlassDialogAction> {
  /// Creates the route.
  GlassDialogRoute({
    required this.actions,
    required this.confirmation,
    this.title,
    this.message,
    this.mode,
    this.capturedThemes,
    this.barrierLabel,
  });

  /// See [GlassDialogCard.title].
  final String? title;

  /// See [GlassDialogCard.message].
  final String? message;

  /// See [GlassDialogCard.actions].
  final List<GlassDialogAction> actions;

  /// See [GlassDialogCard.confirmation].
  final bool confirmation;

  /// The rendering path.
  final GlassRenderMode? mode;

  /// Themes captured from the presenting context, wrapped around the page
  /// so it draws in the caller's appearance; null uses the navigator's.
  final CapturedThemes? capturedThemes;

  @override
  final String? barrierLabel;

  /// A confirmation dialog closes on a tap outside (its cancel action);
  /// an alert only through its buttons, as on iOS.
  @override
  bool get barrierDismissible => confirmation;

  /// SwiftUI dims the page behind an alert (20%), not behind a
  /// confirmation dialog.
  @override
  Color get barrierColor =>
      confirmation ? GlassColors.transparent : GlassColors.sheetBarrier;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final page = iosPageText(
      // Centred in the safe area, as SwiftUI's (y 451 on iPhone 17 Pro).
      SafeArea(
        child: Center(
          child: GlassDialogCard(
            title: title,
            message: message,
            actions: actions,
            confirmation: confirmation,
            mode: mode,
            onAction: (a) => Navigator.of(context).pop(a),
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
    // Reduce Motion: fade without scaling.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return FadeTransition(opacity: animation, child: child);
    }
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curve,
      child: ScaleTransition(
        scale: Tween(begin: 1.1, end: 1.0).animate(curve),
        child: child,
      ),
    );
  }
}
