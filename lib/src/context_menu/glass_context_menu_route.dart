import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_page_text.dart';
import '../menu/glass_menu_item.dart';
import '../menu/glass_menu_panel.dart';
import 'context_menu_grow.dart';
import 'context_menu_metrics.dart';
import 'glass_context_menu_layout.dart';

/// The route a long-press on a `GlassContextMenu` pushes: the page
/// dimmed (UIKit does not blur it), the item lifted where it was, the glass menu by it.
class GlassContextMenuRoute extends PopupRoute<GlassMenuItem> {
  /// Creates the route.
  GlassContextMenuRoute({
    required this.preview,
    required this.previewRect,
    required this.items,
    this.mode,
    this.capturedThemes,
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

  /// Themes captured from the presenting context, wrapped around the page
  /// so it draws in the caller's appearance; null uses the navigator's.
  final CapturedThemes? capturedThemes;

  @override
  final String? barrierLabel;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => GlassColors.transparent;

  @override
  Duration get transitionDuration => ContextMenuMetrics.openDuration;

  @override
  Duration get reverseTransitionDuration => ContextMenuMetrics.closeDuration;

  // The route's linear animation drives UIKit's measured springs: the
  // opening ones from the push, the closing ones from where the opening
  // had got to when the menu began to close.
  double? _closeFrom;
  double _dimFrom = 1, _liftFrom = 1, _menuFrom = 1;

  static double _spring(SpringDescription s, double t) =>
      t <= 0 ? 0 : SpringSimulation(s, 0, 1, 0).x(t);

  static double _seconds(Duration d) => d.inMicroseconds / 1e6;

  double _openT(double v) => v * _seconds(ContextMenuMetrics.openDuration);

  double _closeT(double v) =>
      (_closeFrom! - v) * _seconds(ContextMenuMetrics.closeDuration);

  double get _lead => _seconds(ContextMenuMetrics.openLead);

  double _openDim(double v) => _spring(ContextMenuMetrics.dimSpring, _openT(v));

  double _openLift(double v) =>
      _spring(ContextMenuMetrics.liftSpring, _openT(v) - _lead);

  double _openMenu(double v) =>
      _spring(ContextMenuMetrics.menuSpring, _openT(v) - _lead);

  /// The page's dim, 0..1.
  double _dim(double v) => _closeFrom == null
      ? _openDim(v)
      : _dimFrom * (1 - _spring(ContextMenuMetrics.closeDimSpring, _closeT(v)));

  /// The item's lift, 0 (in place) .. 1 (lifted).
  double _lift(double v) => _closeFrom == null
      ? _openLift(v)
      : _liftFrom *
            (1 - _spring(ContextMenuMetrics.closeLiftSpring, _closeT(v)));

  /// The menu's scale (from its edge by the item) and opacity.
  double _menu(double v) => _closeFrom == null
      ? _openMenu(v)
      : _menuFrom *
            (1 - _closeT(v) / _seconds(ContextMenuMetrics.closeMenuFade)).clamp(
              0.0,
              1.0,
            );

  @override
  void install() {
    super.install();
    animation!.addStatusListener((status) {
      if (status == AnimationStatus.reverse && _closeFrom == null) {
        final v = animation!.value;
        _dimFrom = _openDim(v);
        _liftFrom = _openLift(v);
        _menuFrom = _openMenu(v).clamp(0.0, 1.0);
        _closeFrom = v;
      }
    });
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final padding = MediaQuery.paddingOf(context);
    final lifted = ContextMenuMetrics.lifted(
      previewRect,
      MediaQuery.sizeOf(context),
    );
    final page = iosPageText(
      Stack(
        children: [
          // The page behind, dimmed and left sharp, as UIKit's (measured);
          // a tap closes the menu.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) => ColoredBox(
                  color: GlassColors.contextMenuBarrier.withValues(
                    alpha:
                        GlassColors.contextMenuBarrier.a *
                        _dim(animation.value).clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: previewRect,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) {
                  // From where the item is to where UIKit lifts it.
                  final t = _lift(animation.value);
                  final grow = previewRect.width > 0
                      ? lifted.width / previewRect.width
                      : 1.0;
                  final s = 1 + (grow - 1) * t;
                  return Transform(
                    transform: Matrix4.identity()
                      ..translateByDouble(
                        (lifted.left - previewRect.left) * t,
                        (lifted.top - previewRect.top) * t,
                        0,
                        1,
                      )
                      ..scaleByDouble(s, s, 1, 1),
                    child: child,
                  );
                },
                child: preview,
              ),
            ),
          ),
          CustomSingleChildLayout(
            delegate: GlassContextMenuLayout(preview: lifted, padding: padding),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                final m = _menu(animation.value);
                return Opacity(
                  opacity: m.clamp(0.0, 1.0),
                  child: ContextMenuGrow(
                    scale: math.max(m, 0.0),
                    itemCenterY: lifted.center.dy,
                    child: child,
                  ),
                );
              },
              child: GlassMenuPanel(
                items: items,
                mode: mode,
                onChoose: (item) => Navigator.of(context).pop(item),
              ),
            ),
          ),
        ],
      ),
    );
    return capturedThemes?.wrap(page) ?? page;
  }
}
