import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show HorizontalDragGestureRecognizer, VerticalDragGestureRecognizer;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/widgets.dart';

import 'glass_zoom_page_route.dart';
import 'zoom_transition_metrics.dart';

/// Where the zooming page is: [clip] is the visible rounded frame,
/// [page] where the full-screen page is drawn (scaled) behind it.
@immutable
class ZoomFrame {
  /// Creates a frame.
  const ZoomFrame(this.clip, this.page, this.radius);

  /// The page at rest, filling [screen].
  factory ZoomFrame.full(Size screen) =>
      ZoomFrame(Offset.zero & screen, Offset.zero & screen, BorderRadius.zero);

  /// The page aspect-filled into [rect] (a source's frame), cropped to it.
  factory ZoomFrame.aspectFill(Rect rect, Size screen, BorderRadius radius) {
    final s = math.max(rect.width / screen.width, rect.height / screen.height);
    return ZoomFrame(
      rect,
      Rect.fromCenter(
        center: rect.center,
        width: screen.width * s,
        height: screen.height * s,
      ),
      radius,
    );
  }

  /// The whole page scaled by [scale] about the screen's centre moved by
  /// [offset], with [radius] corners.
  factory ZoomFrame.scaled(
    Size screen,
    double scale,
    Offset offset,
    double radius,
  ) {
    final rect = Rect.fromCenter(
      center: screen.center(Offset.zero) + offset,
      width: screen.width * scale,
      height: screen.height * scale,
    );
    return ZoomFrame(rect, rect, BorderRadius.circular(radius));
  }

  /// The visible frame.
  final Rect clip;

  /// The full page's frame (equal to or around [clip]).
  final Rect page;

  /// [clip]'s corners.
  final BorderRadius radius;

  /// Between [a] and [b].
  static ZoomFrame lerp(ZoomFrame a, ZoomFrame b, double t) => ZoomFrame(
    Rect.lerp(a.clip, b.clip, t)!,
    Rect.lerp(a.page, b.page, t)!,
    BorderRadius.lerp(a.radius, b.radius, t)!,
  );
}

/// The zoom route's flight: places the page between its source's frame
/// and the screen as the route animates, and (when [enabled]) lets a
/// downward drag or a leading-edge swipe shrink it and pop it back into
/// its source. Respects PopScope and child scrollables.
class ZoomDragDismiss extends StatefulWidget {
  /// Creates the flight.
  const ZoomDragDismiss({
    super.key,
    required this.route,
    required this.enabled,
    required this.child,
  });

  /// The route animating.
  final GlassZoomPageRoute<dynamic> route;

  /// Whether drags dismiss.
  final bool enabled;

  /// The page.
  final Widget child;

  @override
  State<ZoomDragDismiss> createState() => _ZoomDragDismissState();
}

class _ZoomDragDismissState extends State<ZoomDragDismiss>
    with SingleTickerProviderStateMixin {
  late CurvedAnimation _curved;

  /// 1 → 0 while a cancelled drag springs back.
  late final AnimationController _settle;

  /// The finger's travel; null when not dragging.
  Offset? _drag;
  Offset _settleFrom = Offset.zero;
  bool _horizontal = false;
  bool _dismissing = false;
  int _settleRevision = 0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController.unbounded(vsync: this);
    _curved = _curve();
  }

  CurvedAnimation _curve() {
    final material = widget.route.isMaterial;
    return CurvedAnimation(
      parent: widget.route.animation!,
      curve: material
          ? ZoomTransitionMetrics.materialCurve
          : ZoomTransitionMetrics.curve,
      reverseCurve: material
          ? ZoomTransitionMetrics.materialCurve.flipped
          : ZoomTransitionMetrics.reverseCurve,
    );
  }

  @override
  void didUpdateWidget(ZoomDragDismiss oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route) {
      _curved.dispose();
      _curved = _curve();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _settle.dispose();
    super.dispose();
  }

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  bool get _settled =>
      widget.route.animation!.status == AnimationStatus.completed;

  // Vertical: a downward drag anywhere (scrollables inside win theirs).
  void _vStart(DragStartDetails d) => _start(horizontal: false);

  // Horizontal: only from the leading edge (the back-swipe strip).
  void _hStart(DragStartDetails d) {
    final width = context.size?.width ?? 0;
    final x = d.localPosition.dx;
    final edge = ZoomTransitionMetrics.edgeWidth;
    if (_rtl ? x >= width - edge : x <= edge) _start(horizontal: true);
  }

  void _start({required bool horizontal}) {
    if (_dismissing || !_settled) return;
    _settleRevision++;
    _settle.stop();
    _horizontal = horizontal;
    setState(() => _drag = _settleFrom * _settle.value);
  }

  void _update(DragUpdateDetails d) {
    final drag = _drag;
    if (drag == null || _dismissing) return;
    setState(() => _drag = drag + d.delta);
  }

  void _cancel() {
    if (_drag != null && !_dismissing) _springBack();
  }

  double _progress(Offset drag, Size size) => _horizontal
      ? (drag.dx * (_rtl ? -1 : 1) / size.width).clamp(0.0, 1.0)
      : (drag.dy / size.height).clamp(0.0, 1.0);

  void _end(DragEndDetails d) {
    final drag = _drag;
    if (drag == null || _dismissing) return;
    final size = context.size ?? Size.zero;
    final v = _horizontal
        ? d.velocity.pixelsPerSecond.dx * (_rtl ? -1 : 1)
        : d.velocity.pixelsPerSecond.dy;
    final p = _progress(drag, size);
    final fling = ZoomTransitionMetrics.flingVelocity;
    final dismiss =
        p > 0 &&
        (v > fling || (p > ZoomTransitionMetrics.dismissFraction && v > -fling));
    if (dismiss) {
      _dismiss(_dragFrame(drag, size));
    } else {
      _springBack();
    }
  }

  /// The page as [drag] has moved and shrunk it.
  ZoomFrame _dragFrame(Offset drag, Size size) {
    final p = _progress(drag, size);
    final scale = 1 - p * (1 - ZoomTransitionMetrics.dragMinScale);
    // Follows the finger along the gesture's axis only; a pull the
    // wrong way barely moves.
    final along = _horizontal ? Offset(drag.dx, 0) : Offset(0, drag.dy);
    final shown = p > 0 ? along : along * 0.1;
    final radius = ZoomTransitionMetrics.dragCornerRadius * math.min(1, p * 4);
    return ZoomFrame.scaled(size, scale, shown, radius);
  }

  void _springBack() {
    final from = _drag ?? Offset.zero;
    final revision = ++_settleRevision;
    setState(() {
      _settleFrom = from;
      _drag = null;
    });
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _settle.value = 0;
      return;
    }
    _settle
      ..value = 1
      ..animateWith(
        SpringSimulation(ZoomTransitionMetrics.spring, 1, 0, 0),
      ).whenComplete(() {
        if (mounted && revision == _settleRevision) _settle.value = 0;
      });
  }

  Future<void> _dismiss([ZoomFrame? from]) async {
    if (_dismissing) return;
    final route = widget.route;
    if (!route.isCurrent) return;
    _dismissing = true;
    route.dismissFrom = from;
    await Navigator.maybePop(context);
    if (!mounted) return;
    if (route.isActive && route.animation?.status != AnimationStatus.reverse) {
      // A PopScope refused: spring back as after a short drag.
      route.dismissFrom = null;
      _dismissing = false;
      if (_drag != null) _springBack();
    }
  }

  ZoomFrame _frame(Size size) {
    final route = widget.route;
    final t = _curved.value;
    final full = ZoomFrame.full(size);
    final f = ZoomTransitionMetrics.fallbackScale;
    final start =
        route.sourceFrame(size) ??
        ZoomFrame.scaled(size, f, Offset.zero, 0);
    final drag = _drag ?? _settleFrom * _settle.value;
    final end =
        route.dismissFrom ??
        (drag == Offset.zero ? full : _dragFrame(drag, size));
    return ZoomFrame.lerp(start, end, t);
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final flight = LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: Listenable.merge([_curved, _settle]),
          builder: (context, child) {
            final t = _curved.value;
            final frame = _frame(size);
            final fade = ZoomTransitionMetrics.crossFade;
            final snapshot = route.snapshot;
            final hasSource = route.sourceFrame(size) != null;
            final pageScale = frame.page.width / size.width;
            final offset = frame.page.topLeft - frame.clip.topLeft;
            final shown = t.clamp(0.0, 1.0);
            final dim = route.isMaterial
                ? 0.0
                : ZoomTransitionMetrics.dim * shown * shown;
            // The page fades in as the source's snapshot fades out; with
            // no source it fades in over the first half.
            final pageOpacity = route.isMaterial
                ? 1.0
                : (shown / (hasSource ? fade : 0.5)).clamp(0.0, 1.0);
            return Stack(
              children: [
                if (dim > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Color.fromRGBO(0, 0, 0, dim),
                      ),
                    ),
                  ),
                Positioned.fromRect(
                  rect: frame.clip,
                  child: ClipRRect(
                    borderRadius: frame.radius,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: offset.dx,
                          top: offset.dy,
                          width: size.width,
                          height: size.height,
                          child: Transform.scale(
                            scale: pageScale,
                            alignment: Alignment.topLeft,
                            child: Opacity(
                              opacity: pageOpacity,
                              child: child,
                            ),
                          ),
                        ),
                        if (snapshot != null && t < fade)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: (1 - t / fade).clamp(0.0, 1.0),
                                // As on iOS: the source keeps its width,
                                // pinned to the top of the growing frame.
                                child: RawImage(
                                  image: snapshot,
                                  fit: BoxFit.fitWidth,
                                  alignment: Alignment.topCenter,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          child: widget.child,
        );
      },
    );
    if (!widget.enabled) return flight;
    return Semantics(
      onDismiss: _dismissing ? null : _dismiss,
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: <Type, GestureRecognizerFactory>{
          VerticalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                VerticalDragGestureRecognizer
              >(
                VerticalDragGestureRecognizer.new,
                (r) => r
                  ..onStart = _vStart
                  ..onUpdate = _update
                  ..onEnd = _end
                  ..onCancel = _cancel,
              ),
          HorizontalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                HorizontalDragGestureRecognizer
              >(
                HorizontalDragGestureRecognizer.new,
                (r) => r
                  ..onStart = _hStart
                  ..onUpdate = _update
                  ..onEnd = _end
                  ..onCancel = _cancel,
              ),
        },
        child: flight,
      ),
    );
  }
}
