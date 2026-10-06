import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_page_text.dart';
import 'glass_sheet_detent.dart';
import 'glass_sheet_frame.dart';

/// The modal route [showGlassSheet] pushes: a dimmed page and a
/// [GlassSheetFrame] sliding up from the bottom. Needs no Material.
class GlassSheetRoute<T> extends PopupRoute<T> {
  /// Creates the route.
  GlassSheetRoute({
    required this.builder,
    required this.detents,
    required this.initialDetent,
    required this.showGrabber,
    required this.isDismissible,
    this.glass,
    this.mode,
    this.barrierLabel,
    super.settings,
  });

  /// Builds the sheet's content.
  final WidgetBuilder builder;

  /// See [GlassSheetFrame.detents].
  final List<GlassSheetDetent> detents;

  /// See [GlassSheetFrame.initialDetent].
  final int initialDetent;

  /// See [GlassSheetFrame.showGrabber].
  final bool showGrabber;

  /// Whether a tap outside or a drag down dismisses the sheet.
  final bool isDismissible;

  /// The sheet's glass.
  final Glass? glass;

  /// The rendering path.
  final GlassRenderMode? mode;

  @override
  final String? barrierLabel;

  @override
  bool get barrierDismissible => isDismissible;

  @override
  Color get barrierColor => GlassColors.sheetBarrier;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => iosPageText(
    context,
    GlassSheetFrame(
      detents: detents,
      initialDetent: initialDetent,
      showGrabber: showGrabber,
      isDismissible: isDismissible,
      glass: glass,
      mode: mode,
      onDismiss: () => Navigator.of(context).pop(),
      child: Builder(builder: builder),
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curve),
      child: child,
    );
  }
}
