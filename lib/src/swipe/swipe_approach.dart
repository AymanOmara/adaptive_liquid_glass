part of 'glass_swipe_actions.dart';

/// [from] approaching [to] exponentially, with SwiftUI's platter time
/// constant ([SwipeMetrics.platterTau]).
class _Approach extends Simulation {
  _Approach(this.from, this.to);

  final double from;
  final double to;

  @override
  double x(double time) =>
      to + (from - to) * math.exp(-time / SwipeMetrics.platterTau);

  @override
  double dx(double time) =>
      -(from - to) /
      SwipeMetrics.platterTau *
      math.exp(-time / SwipeMetrics.platterTau);

  @override
  bool isDone(double time) =>
      time * 1000 >= SwipeMetrics.platterFade.inMilliseconds;
}
