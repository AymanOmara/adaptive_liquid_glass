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
    this.pressedScale = 1,
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

  /// How far the press had grown the item about its centre when the menu
  /// opened: the lift carries on from there (`ContextMenuMetrics.pressed`).
  final double pressedScale;

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
  double _dimFrom = 1, _menuFrom = 1;
  Rect? _liftFrom;

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

  /// Where the item is: from its pressed size to [lifted] on opening,
  /// from wherever it had got back to its own rect on closing.
  Rect _previewAt(double v, Rect lifted) {
    if (_closeFrom == null) {
      final pressed = Rect.fromCenter(
        center: previewRect.center,
        width: previewRect.width * pressedScale,
        height: previewRect.height * pressedScale,
      );
      return Rect.lerp(pressed, lifted, _openLift(v))!;
    }
    return Rect.lerp(
      _liftFrom,
      previewRect,
      _spring(ContextMenuMetrics.closeLiftSpring, _closeT(v)),
    )!;
  }

  Rect? _lifted;

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
        _liftFrom = _previewAt(v, _lifted ?? previewRect);
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
    _lifted = lifted;
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
                  // From where the press left the item to where UIKit
                  // lifts it.
                  final at = _previewAt(animation.value, lifted);
                  final s = previewRect.width > 0
                      ? at.width / previewRect.width
                      : 1.0;
                  return Transform(
                    transform: Matrix4.identity()
                      ..translateByDouble(
                        at.left - previewRect.left,
                        at.top - previewRect.top,
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
