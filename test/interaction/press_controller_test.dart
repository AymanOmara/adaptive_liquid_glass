import 'package:adaptive_liquid_glass/src/group/glass_entry.dart';
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
    expect(g.scaleY, closeTo(1 + motion.motion.pressScale, 0.01));
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
    await t.pump(const Duration(seconds: 1));
    final g = c.geometry();
    expect(g.scaleX, 1);
    expect(g.scaleY, 1);
    expect(g.translation, Offset.zero);
    expect(g.glow, greaterThan(0.9));
  });
}
