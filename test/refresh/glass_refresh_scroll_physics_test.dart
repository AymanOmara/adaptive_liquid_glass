import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/refresh/refresh_metrics.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// A vertical (down) position [overscroll] pixels past the top of a
/// [viewport]-tall scrollable with plenty of content.
ScrollMetrics _at(
  double overscroll, {
  double viewport = 874,
  AxisDirection direction = AxisDirection.down,
}) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: 2000,
  pixels: -overscroll,
  viewportDimension: viewport,
  axisDirection: direction,
  devicePixelRatio: 3,
);

/// The overscroll after the finger travels [travel] pt down from the top
/// in 5-pt steps (idb's `--delta 5`).
double _pull(
  ScrollPhysics physics,
  double travel, {
  double viewport = 874,
  double from = 0,
}) {
  var overscroll = from;
  for (var moved = 0.0; moved < travel; moved += 5) {
    overscroll += physics.applyPhysicsToUserOffset(
      _at(overscroll, viewport: viewport),
      5,
    );
  }
  return overscroll;
}

void main() {
  const physics = GlassRefreshScrollPhysics();

  group('GlassRefreshScrollPhysics', () {
    test("follows UIScrollView's measured rubber band (iOS 26.4)", () {
      // SwiftUI List, 874-pt viewport: finger travel -> content offset.
      const measured = {
        50: 40.0,
        100: 73.7,
        150: 99.3,
        200: 123.7,
        250: 146.7,
        300: 168.3,
      };
      measured.forEach((travel, offset) {
        expect(_pull(physics, travel.toDouble()), closeTo(offset, 3.5));
      });
    });

    test("reaches the refresh's 173 pt at the measured 315 pt of travel", () {
      expect(
        _pull(physics, RefreshMetrics.triggerTravel),
        closeTo(RefreshMetrics.triggerDistance, 2),
      );
    });

    test("pulls further than Flutter's bouncing friction", () {
      expect(
        _pull(physics, 300),
        greaterThan(_pull(const BouncingScrollPhysics(), 300) + 30),
      );
    });

    test('the band scales with the viewport', () {
      expect(_pull(physics, 200, viewport: 437), lessThan(_pull(physics, 200)));
    });

    test('the step does not depend on how the travel is sliced', () {
      var coarse = 0.0;
      for (var i = 0; i < 4; i++) {
        coarse += physics.applyPhysicsToUserOffset(_at(coarse), 50);
      }
      expect(coarse, closeTo(_pull(physics, 200), 0.01));
    });

    test('moving the finger back retraces the band', () {
      final out = _pull(physics, 200);
      final back = physics.applyPhysicsToUserOffset(_at(out), -100);
      expect(out + back, closeTo(_pull(physics, 100), 0.01));
      // Past the top again, the rest scrolls the content 1:1.
      final through = physics.applyPhysicsToUserOffset(_at(out), -250);
      expect(out + through, closeTo(-50, 0.01));
    });

    test('a drag within the content is not damped', () {
      final inside = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 300,
        viewportDimension: 874,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 3,
      );
      expect(physics.applyPhysicsToUserOffset(inside, 40), 40);
      expect(physics.applyPhysicsToUserOffset(inside, -40), -40);
      // Crossing the top: 1:1 up to it, the band beyond.
      final near = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 10,
        viewportDimension: 874,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 3,
      );
      expect(
        physics.applyPhysicsToUserOffset(near, 60),
        closeTo(10 + physics.applyPhysicsToUserOffset(_at(0), 50), 0.01),
      );
    });

    test("other edges and axes keep BouncingScrollPhysics' friction", () {
      const bouncing = BouncingScrollPhysics();
      final sideways = _at(40, direction: AxisDirection.right);
      expect(
        physics.applyPhysicsToUserOffset(sideways, 10),
        bouncing.applyPhysicsToUserOffset(sideways, 10),
      );
      final bottom = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 2040,
        viewportDimension: 874,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 3,
      );
      expect(
        physics.applyPhysicsToUserOffset(bottom, -10),
        bouncing.applyPhysicsToUserOffset(bottom, -10),
      );
    });

    test("a release short of the refresh bounces back as UIKit's", () {
      // SwiftUI List, 60 fps dumps after release: overscroll per frame
      // (null: a repeated frame).
      final takes = {
        97.0: [
          97.0,
          84.3,
          null,
          63.7,
          55.0,
          47.7,
          41.0,
          35.7,
          30.7,
          26.3,
          22.7,
        ],
        121.3: [121.3, 107.0, 94.3, 82.7, 72.3, 63.3, 55.3, 48.0, 41.7],
      };
      takes.forEach((from, frames) {
        final sim = physics.createBallisticSimulation(_at(from), 0)!;
        for (var i = 0; i < frames.length; i++) {
          final measured = frames[i];
          if (measured == null) continue;
          expect(-sim.x(i / 60), closeTo(measured, 2.5), reason: '$from @ $i');
        }
        expect(-sim.x(1), closeTo(0, 0.5));
        // Critically damped: never past the top.
        for (var t = 0.0; t < 2; t += 0.01) {
          expect(sim.x(t), lessThanOrEqualTo(0.01));
        }
      });
      // Flutter's bouncing simulation is far slower to start.
      final flutter = const BouncingScrollPhysics().createBallisticSimulation(
        _at(121.3),
        0,
      )!;
      expect(-flutter.x(4 / 60), greaterThan(72.3 + 10));
    });

    test('a fling up past the launch keeps the bouncing simulation', () {
      const bouncing = BouncingScrollPhysics();
      final fast = physics.createBallisticSimulation(_at(50), 3000)!;
      final reference = bouncing.createBallisticSimulation(_at(50), 3000)!;
      expect(fast.x(0.1), closeTo(reference.x(0.1), 1e-6));
      // Other edges keep it too.
      final bottom = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 2000,
        pixels: 2050,
        viewportDimension: 874,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 3,
      );
      expect(
        physics.createBallisticSimulation(bottom, 0)!.x(0.1),
        closeTo(bouncing.createBallisticSimulation(bottom, 0)!.x(0.1), 1e-6),
      );
    });

    test('applyTo keeps the type and the parent', () {
      final applied = physics.applyTo(const AlwaysScrollableScrollPhysics());
      expect(applied, isA<GlassRefreshScrollPhysics>());
      expect(applied.parent, isA<AlwaysScrollableScrollPhysics>());
    });
  });

  group('GlassRefresh supplies the rubber band', () {
    setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
    tearDown(() => GlassPlatform.instance.debugReset());

    /// The overscroll after the drag slop, and after 150 pt more.
    Future<(double, double)> pullOverscroll(
      WidgetTester t, {
      ScrollPhysics? own,
    }) async {
      shaderEnv();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        plainHost(
          SizedBox(
            width: 300,
            height: 500,
            child: GlassRefresh(
              mode: GlassRenderMode.shader,
              onRefresh: () async {},
              child: ListView(
                controller: controller,
                physics: own,
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 44, child: Text('Row $i')),
                ],
              ),
            ),
          ),
        ),
      );
      final gesture = await t.startGesture(t.getCenter(find.text('Row 2')));
      // Past the drag slop first, then 150 pt in 5-pt steps.
      await gesture.moveBy(const Offset(0, 20));
      await t.pump(const Duration(milliseconds: 16));
      final start = -controller.position.pixels;
      for (var i = 0; i < 30; i++) {
        await gesture.moveBy(const Offset(0, 5));
        await t.pump(const Duration(milliseconds: 16));
      }
      final end = -controller.position.pixels;
      await gesture.up();
      await t.pumpAndSettle();
      return (start, end);
    }

    testWidgets("a default list rubber-bands as UIKit's under a pull", (
      t,
    ) async {
      final (start, end) = await pullOverscroll(t);
      expect(
        end,
        closeTo(_pull(physics, 150, from: start, viewport: 500), 0.5),
      );
      // 150 pt from the top: UIKit 99, Flutter's friction ~72.
      expect(_pull(physics, 150), greaterThan(95));
    }, variant: ios);

    testWidgets('an AlwaysScrollable list gets it too', (t) async {
      final (start, end) = await pullOverscroll(
        t,
        own: const AlwaysScrollableScrollPhysics(),
      );
      expect(
        end,
        closeTo(_pull(physics, 150, from: start, viewport: 500), 0.5),
      );
    }, variant: ios);

    testWidgets('clamping platforms keep their physics', (t) async {
      final (_, end) = await pullOverscroll(t);
      expect(end, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
