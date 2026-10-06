import 'package:adaptive_liquid_glass/src/group/glass_press_geometry.dart';
import 'package:adaptive_liquid_glass/src/interaction/press_controller.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const motion = GlassConstants.standard;

  testWidgets('press grows toward the touch, release springs back', (t) async {
    final c = GlassPressController(
      vsync: const TestVSync(),
      motion: motion.motion,
    );
    addTearDown(c.dispose);
    expect(c.geometry(), same(GlassPressGeometry.identity));

    c.down(
      const Offset(100, 20),
      const Size(100, 40),
    ); // right edge, centre row
    await t.pump(); // ticker starts on the first frame
    await t.pump(const Duration(seconds: 1));
    final g = c.geometry();
    expect(c.amount, closeTo(1, 0.01));
    expect(g.scaleX, greaterThan(g.scaleY)); // stretched along x
    expect(
      g.scaleY,
      closeTo(pressScaleFor(motion.motion, const Size(100, 40)), 0.01),
    );
    expect(g.translation.dx, greaterThan(0));
    expect(g.translation.dy, closeTo(0, 1e-6));
    expect(g.glow, closeTo(1, 0.01));
    expect(g.touch, const Offset(100, 20));

    c.up();
    await t.pump();
    await t.pump(const Duration(seconds: 2));
    expect(c.amount, closeTo(0, 0.01));
  });

  testWidgets('release overshoots below zero (bounce)', (t) async {
    final c = GlassPressController(
      vsync: const TestVSync(),
      motion: motion.motion,
    );
    addTearDown(c.dispose);
    c.down(const Offset(50, 20), const Size(100, 40));
    await t.pump(); // ticker starts on the first frame
    await t.pump(const Duration(seconds: 1));
    c.up();
    await t.pump();
    var min = 1.0;
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 16));
      if (c.amount < min) min = c.amount;
    }
    expect(min, lessThan(0)); // pressDamping < 1 → overshoot
  });

  testWidgets('reduce motion keeps geometry but still glows', (t) async {
    final c = GlassPressController(
      vsync: const TestVSync(),
      motion: motion.motion,
    )..reduceMotion = true;
    addTearDown(c.dispose);
    c.down(const Offset(100, 20), const Size(100, 40));
    await t.pump(); // ticker starts on the first frame
    // Settle: the fitted press spring needs just over 1 s.
    await t.pump(const Duration(seconds: 2));
    final g = c.geometry();
    expect(g.scaleX, 1);
    expect(g.scaleY, 1);
    expect(g.translation, Offset.zero);
    expect(g.glow, greaterThan(0.9));
  });

  test('press scale grows a fixed area, capped (SwiftUI, Task 16b)', () {
    const m = GlassMotionConstants(
      pressGrowthArea: 1800,
      pressScaleMax: 1.36,
      pressStretch: 0,
      glowRadius: 41,
      pressResponse: 0.3,
      pressDamping: 0.6,
      releaseResponse: 0.4,
      releaseDamping: 0.5,
      morphResponse: 0.5,
      morphDamping: 0.7,
    );
    // sqrt(1 + 1800 / (200·56)) = 1.077; a 120 pt circle 1.060.
    expect(pressScaleFor(m, const Size(200, 56)), closeTo(1.077, 0.001));
    expect(pressScaleFor(m, const Size(120, 120)), closeTo(1.0606, 0.001));
    // Small shapes hit the cap.
    expect(pressScaleFor(m, const Size(20, 20)), 1.36);
    expect(pressScaleFor(m, Size.zero), 1.36);
  });

  testWidgets('release follows the release spring', (t) async {
    final slow = GlassMotionConstants.fromJson({
      'pressResponse': 0.1,
      'releaseResponse': 1.5,
      'releaseDamping': 1.0,
    }, motion.motion);
    final c = GlassPressController(vsync: const TestVSync(), motion: slow);
    addTearDown(c.dispose);
    c.down(const Offset(50, 20), const Size(100, 40));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400)); // fast press-in
    expect(c.amount, closeTo(1, 0.02));
    c.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400)); // slow release
    expect(c.amount, greaterThan(0.5));
    await t.pump(const Duration(seconds: 6));
    expect(c.amount, 0);
  });

  testWidgets('press again mid-release springs back up from where it was', (
    t,
  ) async {
    final c = GlassPressController(
      vsync: const TestVSync(),
      motion: motion.motion,
    );
    addTearDown(c.dispose);
    c.down(const Offset(50, 20), const Size(100, 40));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    c.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final mid = c.amount;
    expect(mid, inExclusiveRange(0.05, 0.95));
    c.down(const Offset(50, 20), const Size(100, 40));
    await t.pump();
    // Continuous: no jump at the interruption.
    expect(c.amount, closeTo(mid, 0.05));
    await t.pump(const Duration(seconds: 2));
    expect(c.amount, closeTo(1, 0.01));
  });

  testWidgets('release mid-press returns to rest from where it was', (t) async {
    final c = GlassPressController(
      vsync: const TestVSync(),
      motion: motion.motion,
    );
    addTearDown(c.dispose);
    c.down(const Offset(50, 20), const Size(100, 40));
    await t.pump();
    await t.pump(const Duration(milliseconds: 60));
    final mid = c.amount;
    expect(mid, inExclusiveRange(0.05, 0.95));
    c.up();
    await t.pump();
    expect(c.amount, closeTo(mid, 0.1));
    await t.pump(const Duration(seconds: 3));
    expect(c.amount, 0);
    expect(c.geometry(), same(GlassPressGeometry.identity));
  });

  test('motion constants round-trip through JSON, new fields included', () {
    final m = motion.motion;
    final j = m.toJson();
    for (final k in [
      'pressGrowthArea',
      'pressScaleMax',
      'releaseResponse',
      'releaseDamping',
    ]) {
      expect(j, contains(k));
    }
    expect(GlassMotionConstants.fromJson(j, m), m);
    final other = GlassMotionConstants.fromJson({
      'pressGrowthArea': 900.0,
      'pressScaleMax': 1.2,
      'releaseResponse': 0.5,
      'releaseDamping': 0.9,
    }, m);
    expect(other.pressGrowthArea, 900);
    expect(other.pressScaleMax, 1.2);
    expect(other.releaseResponse, 0.5);
    expect(other.releaseDamping, 0.9);
    expect(other.pressResponse, m.pressResponse);
    expect(GlassMotionConstants.fromJson(other.toJson(), m), other);
    expect(GlassConstants.fromJson(GlassConstants.standard.toJson()).motion, m);
  });

  group('drag past the edge', () {
    Future<GlassPressController> pressed(
      WidgetTester t, {
      bool reduceMotion = false,
    }) async {
      final c = GlassPressController(
        vsync: const TestVSync(),
        motion: motion.motion,
      )..reduceMotion = reduceMotion;
      addTearDown(c.dispose);
      c.down(const Offset(50, 20), const Size(100, 40));
      await t.pump();
      await t.pump(const Duration(seconds: 2));
      return c;
    }

    testWidgets('inside the shape: no extra stretch', (t) async {
      final c = await pressed(t);
      c.move(const Offset(100, 20)); // on the right edge
      final edge = c.geometry();
      final s = pressScaleFor(motion.motion, const Size(100, 40));
      expect(edge.scaleX, closeTo(s + motion.motion.pressStretch, 1e-9));
      expect(
        edge.translation.dx,
        closeTo(motion.motion.pressStretch * 100 / 4, 1e-9),
      );
    });

    testWidgets('rubber-bands toward the finger, bounded and decaying', (
      t,
    ) async {
      final c = await pressed(t);
      c.move(const Offset(100, 20));
      final edge = c.geometry();
      c.move(const Offset(130, 20)); // 30 pt past the right edge
      final near = c.geometry();
      c.move(const Offset(160, 20));
      final mid = c.geometry();
      c.move(const Offset(5000, 20));
      final far = c.geometry();
      expect(near.scaleX, greaterThan(edge.scaleX));
      expect(near.translation.dx, greaterThan(edge.translation.dx));
      expect(near.scaleY, closeTo(edge.scaleY, 1e-9)); // x only
      // Diminishing returns: the second 30 pt add less than the first.
      expect(mid.scaleX - near.scaleX, lessThan(near.scaleX - edge.scaleX));
      // Bounded by dragStretch.
      expect(
        far.scaleX - edge.scaleX,
        closeTo(motion.motion.dragStretch, 1e-6),
      );
      // Anchored: the left edge stays where it was at the edge press.
      double left(GlassPressGeometry g) =>
          50 + g.translation.dx - 50 * g.scaleX;
      expect(left(far), closeTo(left(edge), 1e-6));
      // Leftward and upward drags stretch the other way.
      c.move(const Offset(-40, -40));
      final up = c.geometry();
      expect(up.translation.dx, lessThan(0));
      expect(up.translation.dy, lessThan(0));
      expect(up.scaleY, greaterThan(edge.scaleY));
    });

    testWidgets('springs back on release', (t) async {
      final c = await pressed(t);
      c.move(const Offset(200, 20));
      c.up();
      await t.pump();
      await t.pump(const Duration(seconds: 3));
      expect(c.geometry(), same(GlassPressGeometry.identity));
    });

    testWidgets('reduce motion: no deformation when dragged out', (t) async {
      final c = await pressed(t, reduceMotion: true);
      c.move(const Offset(300, 200));
      final g = c.geometry();
      expect(g.scaleX, 1);
      expect(g.scaleY, 1);
      expect(g.translation, Offset.zero);
    });

    test('drag stretch constants round-trip through JSON', () {
      final m = GlassMotionConstants.fromJson({
        'dragStretch': 0.1,
        'dragStretchDistance': 40.0,
      }, motion.motion);
      expect(m.dragStretch, 0.1);
      expect(m.dragStretchDistance, 40);
      expect(GlassMotionConstants.fromJson(m.toJson(), motion.motion), m);
    });
  });
}
