import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, Theme;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_page_text.dart';
import 'glass_tip.dart';
import 'glass_tip_controller.dart';
import 'tip_body.dart';
import 'tip_metrics.dart';

/// A tip that points at [child], like TipKit's `.popoverTip`: once [child]
/// is laid out, a bubble with an arrow opens above it (below when there is
/// no room), unless the [controller] is dismissed.
///
/// ```dart
/// GlassPopoverTip(
///   tip: favoriteTip,
///   controller: favoriteTipController,
///   child: GlassButton.icon(icon: CupertinoIcons.star, onPressed: save),
/// )
/// ```
///
/// The close button and a tap outside dismiss the [controller] with
/// [GlassTipDismissReason.closed]; dismissing it elsewhere (say, from an
/// action) closes the bubble, and resetting it opens the bubble again.
/// Removing this widget closes the bubble without dismissing. Like
/// TipKit's, the bubble is opaque, not glass. On the Material path it is
/// a Material 3 card without an arrow.
class GlassPopoverTip extends StatefulWidget {
  /// Creates a popover tip anchored to [child].
  const GlassPopoverTip({
    super.key,
    required this.tip,
    this.controller,
    this.closeLabel = 'Close',
    this.mode,
    required this.child,
  });

  /// What the tip says.
  final GlassTip tip;

  /// Whether the tip shows; persist it through
  /// [GlassTipController.onDismissed].
  final GlassTipController? controller;

  /// The close button's accessibility label; pass your localised "Close".
  final String closeLabel;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  /// The widget the tip points at.
  final Widget child;

  @override
  State<GlassPopoverTip> createState() => _GlassPopoverTipState();
}

class _GlassPopoverTipState extends State<GlassPopoverTip> {
  GlassTipController? _local;
  _TipRoute? _route;
  bool _opening = false;

  GlassTipController get _controller =>
      widget.controller ?? (_local ??= GlassTipController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _scheduleOpen();
  }

  @override
  void didUpdateWidget(GlassPopoverTip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.controller ?? _local;
    if (!identical(old, _controller)) {
      old?.removeListener(_changed);
      _controller.addListener(_changed);
      _changed();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    _close();
    _local?.dispose();
    super.dispose();
  }

  void _changed() {
    if (_controller.isDismissed) {
      _close();
    } else {
      _scheduleOpen();
    }
  }

  void _scheduleOpen() {
    if (_opening || _route != null || _controller.isDismissed) return;
    _opening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _opening = false;
      if (mounted) _open();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _open() {
    if (_route != null || _controller.isDismissed) return;
    final box = context.findRenderObject() as RenderBox?;
    final navigator = Navigator.maybeOf(context);
    if (box == null || !box.hasSize || navigator == null) return;
    final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
    final anchor = MatrixUtils.transformRect(
      box.getTransformTo(overlay),
      Offset.zero & box.size,
    );
    final controller = _controller;
    final route = _TipRoute(
      anchor: anchor,
      tip: widget.tip,
      closeLabel: widget.closeLabel,
      mode: widget.mode,
      onClose: () => controller.dismiss(),
      textDirection: Directionality.of(context),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    );
    _route = route;
    navigator.push(route).then((_) {
      if (identical(_route, route)) _route = null;
      // A tap outside pops the route; that dismisses, as TipKit's does.
      if (!route.closedByOwner) controller.dismiss();
    });
  }

  void _close() {
    final route = _route;
    if (route == null) return;
    _route = null;
    route.closedByOwner = true;
    final navigator = route.navigator;
    if (navigator == null || !route.isActive) return;
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The popover route: an undimmed, tap-outside-to-dismiss layer with the
/// bubble beside the anchor.
class _TipRoute extends PopupRoute<void> {
  _TipRoute({
    required this.anchor,
    required this.tip,
    required this.closeLabel,
    required this.mode,
    required this.onClose,
    required this.textDirection,
    required this.capturedThemes,
  });

  final Rect anchor;
  final GlassTip tip;
  final String closeLabel;
  final GlassRenderMode? mode;
  final VoidCallback onClose;
  final TextDirection textDirection;
  final CapturedThemes capturedThemes;

  /// Whether the owning widget closed it (no dismissal follows).
  bool closedByOwner = false;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => GlassColors.transparent;

  @override
  String? get barrierLabel => closeLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => capturedThemes.wrap(
    // The anchor's direction, which a route under the navigator may not
    // inherit.
    Directionality(
      textDirection: textDirection,
      child: iosPageText(
        GlassModeBuilder(
          mode: mode,
          builder: (context, effective) => _TipBubble(
            anchor: anchor,
            animation: animation,
            material: effective == EffectiveGlassMode.material,
            child: TipBody(
              tip: tip,
              onClose: onClose,
              closeLabel: closeLabel,
              material: effective == EffectiveGlassMode.material,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The bubble, placed beside [anchor] and animated in from its arrow.
class _TipBubble extends StatelessWidget {
  const _TipBubble({
    required this.anchor,
    required this.animation,
    required this.material,
    required this.child,
  });

  final Rect anchor;
  final Animation<double> animation;
  final bool material;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    const margin = TipMetrics.popoverScreenMargin;
    final width = math.min(
      screen.width - 2 * margin,
      TipMetrics.popoverMaxWidth,
    );
    final left = (anchor.center.dx - width / 2)
        .clamp(margin, math.max(margin, screen.width - margin - width))
        .toDouble();
    final above = anchor.top - padding.top >= TipMetrics.popoverAboveRoom;
    final arrowHeight = material ? 0.0 : TipMetrics.arrowHeight;
    final gap = material ? 8.0 : TipMetrics.arrowGap;
    final arrowX = (anchor.center.dx - left)
        .clamp(
          TipMetrics.cornerRadius + TipMetrics.arrowWidth / 2,
          width - TipMetrics.cornerRadius - TipMetrics.arrowWidth / 2,
        )
        .toDouble();

    final Widget bubble;
    if (material) {
      final scheme = Theme.of(context).colorScheme;
      bubble = Material(
        color: scheme.surfaceContainerHigh,
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    } else {
      bubble = DecoratedBox(
        decoration: ShapeDecoration(
          color: CupertinoDynamicColor.resolve(
            TipMetrics.popoverBackground,
            context,
          ),
          shadows: const [
            BoxShadow(
              color: TipMetrics.popoverShadow,
              blurRadius: 40,
              offset: Offset(0, 8),
            ),
          ],
          shape: _BubbleBorder(arrowX: arrowX, above: above),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            top: above ? 0 : arrowHeight,
            bottom: above ? arrowHeight : 0,
          ),
          child: child,
        ),
      );
    }

    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    Widget animated = FadeTransition(opacity: curved, child: bubble);
    if (!reduceMotion) {
      animated = ScaleTransition(
        scale: Tween(begin: 0.6, end: 1.0).animate(curved),
        alignment: Alignment(arrowX / width * 2 - 1, above ? 1 : -1),
        child: animated,
      );
    }
    final content = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: animated,
    );
    return Stack(
      children: [
        Positioned(
          left: left,
          width: width,
          top: above ? null : anchor.bottom + gap,
          bottom: above ? screen.height - anchor.top + gap : null,
          child: content,
        ),
      ],
    );
  }
}

/// A rounded rectangle with an arrow on its top or bottom edge at [arrowX].
class _BubbleBorder extends ShapeBorder {
  const _BubbleBorder({required this.arrowX, required this.above});

  final double arrowX;
  final bool above;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    const h = TipMetrics.arrowHeight;
    const half = TipMetrics.arrowWidth / 2;
    final body = above
        ? Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom - h)
        : Rect.fromLTRB(rect.left, rect.top + h, rect.right, rect.bottom);
    final x = rect.left + arrowX;
    final baseY = above ? body.bottom : body.top;
    final tipY = above ? rect.bottom : rect.top;
    // A softened triangle: straight flanks, a rounded point.
    const round = 0.18;
    final arrow = Path()
      ..moveTo(x - half, baseY)
      ..lineTo(x - half * round, tipY + (baseY - tipY) * round)
      ..quadraticBezierTo(
        x,
        tipY,
        x + half * round,
        tipY + (baseY - tipY) * round,
      )
      ..lineTo(x + half, baseY)
      ..close();
    return Path.combine(
      PathOperation.union,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          body,
          const Radius.circular(TipMetrics.cornerRadius),
        ),
      ),
      arrow,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;

  @override
  bool operator ==(Object other) =>
      other is _BubbleBorder && other.arrowX == arrowX && other.above == above;

  @override
  int get hashCode => Object.hash(arrowX, above);
}
