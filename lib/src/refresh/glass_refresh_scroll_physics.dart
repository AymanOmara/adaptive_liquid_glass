import 'dart:math' as math;

import 'package:flutter/widgets.dart';

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
/// List on iOS 26.4). Moving the finger back retraces the curve. Every
/// other edge, the release and the bounce back are
/// `BouncingScrollPhysics`'.
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
