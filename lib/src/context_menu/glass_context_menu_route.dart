import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_page_text.dart';
import '../menu/glass_menu_item.dart';
import '../menu/glass_menu_panel.dart';
import 'context_menu_metrics.dart';
import 'glass_context_menu_layout.dart';

/// The route a long-press on a `GlassContextMenu` pushes: the page
/// blurred and dimmed, the item lifted where it was, the glass menu by it.
class GlassContextMenuRoute extends PopupRoute<GlassMenuItem> {
  /// Creates the route.
  GlassContextMenuRoute({
    required this.preview,
    required this.previewRect,
    required this.items,
    this.mode,
    this.barrierLabel,
  });

  /// The lifted item.
  final Widget preview;

  /// Where the item is, in global coordinates.
  final Rect previewRect;

  /// The menu's rows.
  final List<GlassMenuItem> items;

  /// The rendering path.
  final GlassRenderMode? mode;

  @override
  final String? barrierLabel;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => GlassColors.transparent;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final padding = MediaQuery.paddingOf(context);
    return iosPageText(
      context,
      Stack(
        children: [
          // The page behind, blurred and dimmed; a tap closes the menu.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final sigma = ContextMenuMetrics.blur * animation.value;
                  return BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: ColoredBox(
                      color: GlassColors.sheetBarrier.withValues(
                        alpha: GlassColors.sheetBarrier.a * animation.value,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned.fromRect(
            rect: previewRect,
            child: IgnorePointer(
              child: ScaleTransition(
                scale: Tween(
                  begin: 1.0,
                  end: ContextMenuMetrics.lift,
                ).animate(animation),
                child: preview,
              ),
            ),
          ),
          CustomSingleChildLayout(
            delegate: GlassContextMenuLayout(
              preview: previewRect,
              padding: padding,
            ),
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.5, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                alignment: Alignment.topCenter,
                child: GlassMenuPanel(
                  items: items,
                  mode: mode,
                  onChoose: (item) => Navigator.of(context).pop(item),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
