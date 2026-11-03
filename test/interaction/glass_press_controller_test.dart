import 'dart:math' as math;

import 'package:adaptive_liquid_glass/src/group/glass_press_geometry.dart';
import 'package:adaptive_liquid_glass/src/interaction/glass_press_controller.dart';
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
    c.down(const Offset(100, 28), const Size(200, 56));
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

  testWidgets("the press light is SwiftUI's: on at once, held past release", (
    t,
  ) async {
    final c = GlassPressController(
      vsync: const TestVSync(),
      motion: motion.motion,
    );
    addTearDown(c.dispose);
    expect(c.light, 0);
    c.down(const Offset(100, 28), const Size(200, 56));
    // Full in the frame of the touch, before the press spring has moved.
    expect(c.light, 1);
    expect(c.geometry().light, 1);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));

    c.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 160));
    expect(c.light, closeTo(1 - kPressLightHoldFade / 2, 0.05));
    await t.pump(const Duration(milliseconds: 160));
    expect(c.light, closeTo(1 - kPressLightHoldFade, 0.02));
    await t.pump(const Duration(milliseconds: 20));
    // Off within a frame of the hold, while the release spring still runs.
    expect(c.light, 0);
    expect(c.geometry().light, 0);
    expect(c.amount.abs(), greaterThan(1e-3));

    // A new press mid-hold lights it fully again.
    c.down(const Offset(100, 28), const Size(200, 56));
    c.up();
    c.down(const Offset(100, 28), const Size(200, 56));
    expect(c.light, 1);
    await t.pumpAndSettle();
  });

  testWidgets('small shapes stay lit longer and release springier', (t) async {
    final c = GlassPressController(
      vsync: const TestVSync(),
      motion: motion.motion,
    );
    addTearDown(c.dispose);
    c.down(const Offset(22, 22), const Size(44, 44));
    await t.pump();
    // The frost leads the spring: most of it two frames in.
    await t.pump(const Duration(milliseconds: 33));
    expect(c.frost, greaterThan(0.6));
    expect(c.frost, greaterThan(c.amount));
    await t.pump(const Duration(milliseconds: 467));
    expect(c.geometry().released, 0);
    expect(c.geometry().frost, closeTo(1, 1e-3));
    c.up();
    await t.pump();
    // It eases off without following the release spring's rebound.
    var last = c.frost;
    final frostEnd = kPressLightHoldSmall * kPressFrostRelease;
    for (
      var e = Duration.zero;
      e < frostEnd;
      e += const Duration(milliseconds: 16)
    ) {
      await t.pump(const Duration(milliseconds: 16));
      expect(c.frost, lessThanOrEqualTo(last));
      last = c.frost;
    }
    await t.pump(const Duration(milliseconds: 20));
    expect(c.frost, 0);
    await t.pump(
      kPressLightHold +
          const Duration(milliseconds: 20) -
          frostEnd -
          const Duration(milliseconds: 36),
    );
    // The hold's progress, for the native glow fade.
    expect(
      c.geometry().released,
      closeTo(
        (kPressLightHold.inMilliseconds + 20) /
            kPressLightHoldSmall.inMilliseconds,
        0.05,
      ),
    );
    // Past the capsule hold, still lit.
    expect(c.light, greaterThan(1 - kPressLightHoldFade));
    await t.pump(kPressLightHoldSmall - kPressLightHold);
    expect(c.light, 0);

    // The release overshoots rest further than a large shape's.
    Future<double> undershoot(Size size) async {
      c.down(size.center(Offset.zero), size);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      c.up();
      var least = 1.0;
      for (var i = 0; i < 60; i++) {
        await t.pump(const Duration(milliseconds: 16));
        least = math.min(least, c.amount);
      }
      return -least;
    }

    final small = await undershoot(const Size(44, 44));
    final large = await undershoot(const Size(200, 56));
    expect(small, greaterThan(large * 2));
    await t.pumpAndSettle();
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

  test('press scale grows the long side by L / sqrt(short side)', () {
    final m = motion.motion;
    expect(m.pressGrowthLength, 107.6);
    // SwiftUI (native-mode recordings, 2026-11-03): 1.070 and 1.132.
    expect(pressScaleFor(m, const Size(200, 56)), closeTo(1.0719, 0.001));
    expect(pressScaleFor(m, const Size(44, 120)), closeTo(1.1352, 0.001));
    expect(pressScaleFor(m, const Size(120, 120)), closeTo(1.0819, 0.001));
    expect(pressScaleFor(m, const Size(20, 20)), 1.36);
  });

  test('small shapes grow by a fixed length', () {
    final m = motion.motion;
    expect(m.pressSmallLength, 112);
    // SwiftUI: 72 pt circle 1.222, 72×44 capsule 1.218, 104 pt circle 1.150.
    expect(pressScaleFor(m, const Size(72, 72)), closeTo(1.218, 0.001));
    expect(pressScaleFor(m, const Size(72, 44)), closeTo(1.218, 0.001));
    expect(pressScaleFor(m, const Size(104, 104)), closeTo(1.151, 0.001));
    expect(pressScaleFor(m, const Size(44, 44)), closeTo(1.357, 0.001));
    final off = GlassMotionConstants.fromJson({'pressSmallGrowth': 0}, m);
    expect(pressScaleFor(off, const Size(72, 72)), closeTo(1.1761, 0.001));
  });

  testWidgets('release follows the release spring', (t) async {
    final slow = GlassMotionConstants.fromJson({
      'pressResponse': 0.1,
      'releaseResponse': 1.5,
      'releaseDamping': 1.0,
    }, motion.motion);
    final c = GlassPressController(vsync: const TestVSync(), motion: slow);
    addTearDown(c.dispose);
    c.down(const Offset(100, 28), const Size(200, 56));
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
    c.down(const Offset(100, 28), const Size(200, 56));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    c.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final mid = c.amount;
    expect(mid, inExclusiveRange(0.05, 0.95));
    c.down(const Offset(100, 28), const Size(200, 56));
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
    c.down(const Offset(100, 28), const Size(200, 56));
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
