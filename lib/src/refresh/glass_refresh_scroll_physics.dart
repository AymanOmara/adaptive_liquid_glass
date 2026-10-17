import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../core/swiftui_spring.dart';
import 'refresh_metrics.dart';

/// `BouncingScrollPhysics` with UIScrollView's rubber band under a pull
/// from the top, so a pull to refresh moves the content as far as iOS's
/// does for the same finger travel.
///
/// [GlassRefresh] supplies it to a scrollable that inherits bouncing
/// physics (the default on iOS). Pass it yourself when the scrollable
/// sets its own physics, or for [SliverGlassRefresh]:
///
/// ```dart
/// CustomScrollView(
///   physics: const AlwaysScrollableScrollPhysics(
///     parent: GlassRefreshScrollPhysics(),
///   ),
///   slivers: [...],
/// )
/// ```
///
/// Only a vertical scrollable's top overscroll changes: the content
/// follows `r × (1 − 1 / (x × c / r + 1))` for a finger travel `x` past the
/// top, with `c` = [RefreshMetrics.rubberBandStiffness] and `r` =
/// [RefreshMetrics.rubberBandReach] of the viewport (fitted to UIKit's
/// List on iOS 26.4). Moving the finger back retraces the curve.
///
/// Released past the top, the content springs back as UIScrollView's
/// does: critically damped ([RefreshMetrics.bounceResponse]), already
/// moving toward the rest ([RefreshMetrics.bounceLaunch]); a fling up
/// faster than that start sets the spring's speed instead. A spring fast
/// enough to reach the top carries on into the content on
/// `BouncingScrollPhysics`' deceleration from there. Every other edge
/// keeps `BouncingScrollPhysics`' simulation.
class GlassRefreshScrollPhysics extends BouncingScrollPhysics {
  /// Creates the physics.
  const GlassRefreshScrollPhysics({super.decelerationRate, super.parent});

  @override
  GlassRefreshScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      GlassRefreshScrollPhysics(
        decelerationRate: decelerationRate,
        parent: buildParent(ancestor),
      );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final overscroll = position.minScrollExtent - position.pixels;
    if (position.axisDirection != AxisDirection.down || overscroll <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }
    final spring = swiftUISpring(
      response: RefreshMetrics.bounceResponse,
      dampingFraction: RefreshMetrics.bounceDamping,
    );
    final launch =
        RefreshMetrics.bounceLaunch *
        (2 * math.pi / RefreshMetrics.bounceResponse) *
        overscroll;
    final back = ScrollSpringSimulation(
      spring,
      position.pixels,
      position.minScrollExtent,
      math.max(velocity, launch),
      tolerance: toleranceFor(position),
    );
    final reach = _reachTop(back, position.minScrollExtent);
    if (reach == null) return back;
    final on = super.createBallisticSimulation(
      position.copyWith(pixels: position.minScrollExtent),
      back.dx(reach),
    );
    return on == null ? back : _HandOffSimulation(back, reach, on);
  }

  /// When [spring] first reaches [top], or null if it settles short of
  /// it (a critically damped spring passes its rest only when launched
  /// faster than its angular frequency times the distance).
  static double? _reachTop(Simulation spring, double top) {
    const step = 1 / 240;
    var before = 0.0;
    for (var t = step; t < 2; t += step) {
      if (spring.x(t) < top) {
        before = t;
        continue;
      }
      var after = t;
      for (var i = 0; i < 30; i++) {
        final mid = (before + after) / 2;
        if (spring.x(mid) < top) {
          before = mid;
        } else {
          after = mid;
        }
      }
      // The spring settles on [top]: reaching it at rest is no hand-off.
      return spring.dx(after) > 1 ? after : null;
    }
    return null;
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final overscroll = position.minScrollExtent - position.pixels;
    final pulling =
        position.axisDirection == AxisDirection.down &&
        (overscroll > 0 || (offset > 0 && offset > -overscroll));
    if (!pulling || offset == 0) {
      return super.applyPhysicsToUserOffset(position, offset);
    }
    final reach = RefreshMetrics.rubberBandReach * position.viewportDimension;
    if (reach <= 0) return super.applyPhysicsToUserOffset(position, offset);
    const stiffness = RefreshMetrics.rubberBandStiffness;
    // The content scrolls freely up to the top; the rest of the finger's
    // travel stretches the band.
    final free = overscroll < 0 ? -overscroll : 0.0;
    final from = math.max(0.0, overscroll);
    final travel =
        reach / stiffness * (1 / (1 - math.min(from / reach, 0.999)) - 1) +
        offset -
        free;
    if (travel <= 0) {
      // Back past the top: the band is undone and the rest scrolls 1:1.
      return travel - from;
    }
    final to = reach * (1 - 1 / (travel * stiffness / reach + 1));
    return free + to - from;
  }
}

/// [first] until [at], then [then] from where [first] left off.
class _HandOffSimulation extends Simulation {
  _HandOffSimulation(this.first, this.at, this.then)
    : super(tolerance: first.tolerance);

  final Simulation first;
  final double at;
  final Simulation then;

  @override
  double x(double time) => time < at ? first.x(time) : then.x(time - at);

  @override
  double dx(double time) => time < at ? first.dx(time) : then.dx(time - at);

  @override
  bool isDone(double time) => time >= at && then.isDone(time - at);
}
