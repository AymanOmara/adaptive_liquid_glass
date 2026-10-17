import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'glass_refresh_scroll_physics.dart';

/// Gives a scrollable whose own `BouncingScrollPhysics` take the pull
/// from the top (a `physics:` argument, or a [SliverGlassRefresh]'s
/// `CustomScrollView`, which no wrapper can reach) the same pull as
/// [GlassRefreshScrollPhysics]: UIScrollView's rubber band under the
/// finger and its bounce back once released.
///
/// Physics passed to a scrollable outrank any inherited ones, so this
/// works on its position: while a finger that went down on the
/// scrollable drags it past the top, each step is recovered from the
/// scrollable's own friction and re-applied on the band; on release past
/// the top the bounce is restarted on [GlassRefreshScrollPhysics]'
/// simulation, at the finger's speed as the scrollable measures it.
class UIKitPullAdapter {
  ScrollableState? _scrollable;
  ScrollPosition? _position;

  /// The pixels after the last step, as corrected.
  double? _last;

  /// The fingers down on the scrollable.
  final _fingers = <int, VelocityTracker>{};

  /// Follows [scrollable] (null to stop); a no-op while it already does.
  void attach(ScrollableState? scrollable) {
    final position = scrollable?.position;
    if (identical(scrollable, _scrollable) && identical(position, _position)) {
      return;
    }
    final wasAttached = _scrollable != null;
    // A scrollable replaces its position as its physics change; the
    // fingers on it stay down.
    if (!identical(scrollable, _scrollable)) _fingers.clear();
    _position?.removeListener(_onScroll);
    _scrollable = scrollable;
    _position = position?..addListener(_onScroll);
    _last = position != null && position.hasPixels ? position.pixels : null;
    final router = GestureBinding.instance.pointerRouter;
    if (scrollable != null && !wasAttached) {
      router.addGlobalRoute(_onPointer);
    } else if (scrollable == null && wasAttached) {
      router.removeGlobalRoute(_onPointer);
    }
  }

  /// Stops following the scrollable.
  void dispose() => attach(null);

  /// The bouncing physics that take the scrollable's pull, when they are
  /// not already [GlassRefreshScrollPhysics]: null for anything else.
  static BouncingScrollPhysics? _bouncing(ScrollPosition position) {
    if (position.axisDirection != AxisDirection.down) return null;
    for (ScrollPhysics? p = position.physics; p != null; p = p.parent) {
      if (p is BouncingScrollPhysics) {
        return p is GlassRefreshScrollPhysics ? null : p;
      }
    }
    return null;
  }

  // A global route sees each event after the scrollable's recognizer: a
  // release has already started the scrollable's own ballistic.
  void _onPointer(PointerEvent event) {
    if (event is PointerDownEvent) {
      if (_hits(event.position)) {
        final context = _scrollable!.context;
        _fingers[event.pointer] =
            ScrollConfiguration.of(context).velocityTrackerBuilder(context)(
              event,
            )..addPosition(event.timeStamp, event.position);
      }
    } else if (event is PointerMoveEvent) {
      _fingers[event.pointer]?.addPosition(event.timeStamp, event.position);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      final finger = _fingers.remove(event.pointer);
      if (finger != null && _fingers.isEmpty && event is PointerUpEvent) {
        _release(finger);
      }
    }
  }

  bool _hits(Offset global) {
    final box = _scrollable?.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(global));
  }

  void _onScroll() {
    final position = _position!;
    if (!position.hasPixels) return;
    final before = _last;
    final now = position.pixels;
    _last = now;
    if (before == null || _fingers.isEmpty) return;
    final top = position.minScrollExtent;
    if (before >= top && now >= top) return;
    final bouncing = _bouncing(position);
    if (bouncing == null) return;
    final from = position.copyWith(pixels: before);
    final finger = _fingerTravel(position.physics, from, before - now);
    final band = GlassRefreshScrollPhysics(
      decelerationRate: bouncing.decelerationRate,
    ).applyPhysicsToUserOffset(from, finger);
    final corrected = before - band;
    if ((corrected - now).abs() < precisionErrorTolerance) return;
    _last = corrected;
    position.correctBy(corrected - now);
  }

  /// The finger's travel that [physics] turned into [moved] from [from]:
  /// its friction inverted (it grows with the travel).
  static double _fingerTravel(
    ScrollPhysics physics,
    ScrollMetrics from,
    double moved,
  ) {
    double applied(double travel) =>
        physics.applyPhysicsToUserOffset(from, travel);
    if (moved == 0 || applied(moved) == moved) return moved;
    // Friction only shortens the step: the travel is at least [moved].
    var near = 0.0;
    var far = moved;
    for (var i = 0; i < 30 && applied(far).abs() < moved.abs(); i++) {
      near = far;
      far *= 2;
    }
    for (var i = 0; i < 50; i++) {
      final mid = (near + far) / 2;
      if (applied(mid).abs() < moved.abs()) {
        near = mid;
      } else {
        far = mid;
      }
    }
    return (near + far) / 2;
  }

  void _release(VelocityTracker finger) {
    final position = _position;
    if (position is! ScrollPositionWithSingleContext || !position.hasPixels) {
      return;
    }
    if (position.pixels >= position.minScrollExtent) return;
    final bouncing = _bouncing(position);
    if (bouncing == null) return;
    // As the drag's end reads it: a fling below the minimum is none.
    final physics = position.physics;
    var speed = finger.getVelocity().pixelsPerSecond.dy;
    if (speed.abs() < physics.minFlingVelocity) speed = 0;
    speed = speed.clamp(-physics.maxFlingVelocity, physics.maxFlingVelocity);
    final simulation = GlassRefreshScrollPhysics(
      decelerationRate: bouncing.decelerationRate,
    ).createBallisticSimulation(position, -speed);
    if (simulation == null) return;
    position.beginActivity(
      BallisticScrollActivity(
        position,
        simulation,
        position.context.vsync,
        position.shouldIgnorePointer,
      ),
    );
  }
}
