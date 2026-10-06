import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../core/glass_motion_constants.dart';
import '../core/swiftui_spring.dart';
import '../group/glass_press_geometry.dart';

/// Uniform scale of a box of [size] at full press: SwiftUI adds about the
/// same area to every pressed shape (Task 16b, measured on circles 44–120 pt
/// and capsules 120–300 pt), so small shapes grow more.
///
/// Internal: not exported from the package; public for tests only.
double pressScaleFor(GlassMotionConstants motion, Size size) {
  final area = size.width * size.height;
  if (area <= 0) return motion.pressScaleMax;
  return math.min(
    motion.pressScaleMax,
    math.sqrt(1 + motion.pressGrowthArea / area),
  );
}

/// Drives `.interactive()`: a spring from 0 (rest) to 1 (pressed).
class GlassPressController extends ChangeNotifier {
  /// Creates a controller.
  GlassPressController({required TickerProvider vsync, required this.motion})
    : _controller = AnimationController.unbounded(vsync: vsync) {
    _controller.addListener(notifyListeners);
  }

  final AnimationController _controller;

  /// Motion constants.
  GlassMotionConstants motion;

  /// When true, only the glow animates (Reduce Motion).
  bool reduceMotion = false;

  Offset? _touch;
  Size _size = Size.zero;

  /// Press amount; may overshoot outside 0..1.
  double get amount => _controller.value;

  /// Pointer went down at [local] on a box of [size].
  void down(Offset local, Size size) {
    _touch = local;
    _size = size;
    _animateTo(1, motion.pressResponse, motion.pressDamping);
  }

  /// Pointer moved while pressed.
  void move(Offset local) {
    _touch = local;
    notifyListeners();
  }

  /// Pointer released or cancelled.
  void up() => _animateTo(0, motion.releaseResponse, motion.releaseDamping);

  void _animateTo(double target, double response, double damping) {
    // The unbounded controller leaves the spring's residual (within its
    // tolerance) as its value; snap to the target once the spring is done so
    // the glass returns to its exact rest geometry.
    _controller
        .animateWith(
          SpringSimulation(
            swiftUISpring(response: response, dampingFraction: damping),
            _controller.value,
            target,
            _controller.velocity,
          ),
        )
        .then((_) => _controller.value = target);
  }

  /// Current deformation; [GlassPressGeometry.identity] at rest.
  GlassPressGeometry geometry() {
    final a = amount;
    if (a.abs() < 1e-4 && !_controller.isAnimating) {
      return GlassPressGeometry.identity;
    }
    final glow = a.clamp(0.0, 1.0);
    if (reduceMotion || _size.isEmpty) {
      return GlassPressGeometry(glow: glow, touch: _touch);
    }
    final centre = _size.center(Offset.zero);
    final touch = _touch ?? centre;
    final dx = ((touch.dx - centre.dx) / (_size.width / 2)).clamp(-1.0, 1.0);
    final dy = ((touch.dy - centre.dy) / (_size.height / 2)).clamp(-1.0, 1.0);
    final s = 1 + (pressScaleFor(motion, _size) - 1) * a;
    // Dragged past an edge: extra elongation toward the finger, anchored at
    // the opposite edge (translate by half the extra growth). Zero while
    // the finger is inside, so in-shape presses are unchanged.
    final ex = _dragStretch(touch.dx - centre.dx, _size.width) * a;
    final ey = _dragStretch(touch.dy - centre.dy, _size.height) * a;
    return GlassPressGeometry(
      scaleX: s + motion.pressStretch * a * dx.abs() + ex.abs(),
      scaleY: s + motion.pressStretch * a * dy.abs() + ey.abs(),
      translation: Offset(
        dx * motion.pressStretch * a * _size.width / 4 + ex * _size.width / 2,
        dy * motion.pressStretch * a * _size.height / 4 + ey * _size.height / 2,
      ),
      glow: glow,
      touch: touch,
    );
  }

  /// Signed extra scale for a touch [offset] from the centre along an axis
  /// of [extent]: zero inside, rising to [GlassMotionConstants.dragStretch]
  /// with diminishing returns past the edge.
  double _dragStretch(double offset, double extent) {
    final past = offset.abs() - extent / 2;
    if (past <= 0 || motion.dragStretchDistance <= 0) return 0;
    final e =
        motion.dragStretch * (1 - math.exp(-past / motion.dragStretchDistance));
    return offset.sign * e;
  }

  /// The same deformation as a transform for the member's content.
  Matrix4 contentTransform() {
    final g = geometry();
    final c = _size.center(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(
        c.dx + g.translation.dx,
        c.dy + g.translation.dy,
        0,
        1,
      )
      ..scaleByDouble(g.scaleX, g.scaleY, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
