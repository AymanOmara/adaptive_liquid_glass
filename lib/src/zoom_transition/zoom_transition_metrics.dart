import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;

import '../core/swiftui_spring.dart';

/// Timing and geometry of iOS 26's zoom navigation transition
/// (`.navigationTransition(.zoom(sourceID:in:))`), fitted to a SwiftUI
/// recording on the iOS 26.4 simulator (`zoommotion` scene): the push
/// tracks a spring(response 0.40, damping 1.0), the pop a
/// spring(0.41, 0.86).
abstract final class ZoomTransitionMetrics {
  /// The push: the page grows out of its source.
  static const Duration duration = Duration(milliseconds: 500);

  /// The pop: the page shrinks back into its source.
  static const Duration reverseDuration = Duration(milliseconds: 400);

  /// The push's progress curve (frame, scale and corner radius).
  static final Curve curve = SpringCurve(
    swiftUISpring(response: 0.40, dampingFraction: 1),
    duration,
  );

  /// The pop's, applied as the route animation runs 1 → 0.
  static final Curve reverseCurve = FlippedCurve(
    SpringCurve(
      swiftUISpring(response: 0.41, dampingFraction: 0.86),
      reverseDuration,
    ),
  );

  /// The share of the flight over which the source's snapshot fades out
  /// as the page fades in (at the start of a push, the end of a pop).
  static const double crossFade = 0.6;

  /// How far the screen under the flight dims when the page is full
  /// size (eased in with the square of progress).
  static const double dim = 0.25;

  /// Without a mounted source the page grows from this share of the
  /// screen, fading in.
  static const double fallbackScale = 0.8;

  /// Material path: the container transform's emphasized timing.
  static const Duration materialDuration = Duration(milliseconds: 400);

  /// Material path's pop.
  static const Duration materialReverseDuration = Duration(milliseconds: 350);

  /// Material path's curve.
  static const Curve materialCurve = Curves.easeInOutCubicEmphasized;

  /// Interactive dismissal: the page's scale at a full-height drag.
  static const double dragMinScale = 0.5;

  /// The dragged page's corner radius.
  static const double dragCornerRadius = 32;

  /// Share of the screen a release must have dragged to dismiss.
  static const double dismissFraction = 0.25;

  /// Release velocity (px/s) that dismisses whatever the distance.
  static const double flingVelocity = 700;

  /// Width of the leading-edge strip a horizontal swipe starts in.
  static const double edgeWidth = 24;

  /// The spring a cancelled drag returns on.
  static final SpringDescription spring = swiftUISpring(
    response: 0.4,
    dampingFraction: 0.86,
  );
}

/// A spring from 0 to 1 at rest, run over [duration] as a [Curve]; it
/// lands exactly on 1 at t = 1.
class SpringCurve extends Curve {
  /// Creates the curve.
  SpringCurve(SpringDescription spring, Duration duration)
    : _sim = SpringSimulation(spring, 0, 1, 0),
      _seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

  final SpringSimulation _sim;
  final double _seconds;

  @override
  double transformInternal(double t) => _sim.x(t * _seconds);

  @override
  double transform(double t) => t >= 1 ? 1 : super.transform(t);
}
