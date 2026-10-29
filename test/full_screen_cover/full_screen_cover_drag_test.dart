import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart'
    show GlassFullScreenCoverDragConfiguration;
import 'package:adaptive_liquid_glass/src/full_screen_cover/full_screen_cover_drag_dismiss.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

const page = ValueKey('drag-page');
Widget host({
  bool enabled = true,
  bool reducedMotion = false,
  GlassFullScreenCoverDragConfiguration configuration =
      const GlassFullScreenCoverDragConfiguration(),
}) => CupertinoApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
    child: child!,
  ),
  home: FullScreenCoverDragDismiss(
    enabled: enabled,
    configuration: configuration,
    child: const ColoredBox(key: page, color: Color(0xFFFFFFFF)),
  ),
);

void main() {
  test(
    'drag configuration validates bounds and supports distance-only release',
    () {
      expect(
        () => GlassFullScreenCoverDragConfiguration(dismissFraction: 0),
        throwsAssertionError,
      );
      expect(
        () => GlassFullScreenCoverDragConfiguration(dismissFraction: 1.1),
        throwsAssertionError,
      );
      expect(
        () => GlassFullScreenCoverDragConfiguration(flingVelocity: 0),
        throwsAssertionError,
      );
      expect(
        () => GlassFullScreenCoverDragConfiguration(upwardResistance: -0.1),
        throwsAssertionError,
      );
      expect(
        () => GlassFullScreenCoverDragConfiguration(upwardResistance: 1.1),
        throwsAssertionError,
      );
      expect(
        const GlassFullScreenCoverDragConfiguration(
          flingVelocity: double.infinity,
        ).flingVelocity,
        double.infinity,
      );
    },
  );

  testWidgets('upward resistance is independent of pointer-event frequency', (
    t,
  ) async {
    await t.pumpWidget(host());
    Future<double> travel(int count) async {
      final g = await t.startGesture(t.getCenter(find.byKey(page)));
      await g.moveBy(const Offset(0, -20));
      for (var i = 0; i < count; i++) {
        await g.moveBy(Offset(0, -100 / count));
      }
      await t.pump();
      final y = t.getTopLeft(find.byKey(page)).dy;
      await g.cancel();
      await t.pumpAndSettle();
      return y;
    }

    final one = await travel(1);
    final many = await travel(20);
    expect(one, closeTo(-36, 0.01));
    expect(many, closeTo(one, 0.01));
  });

  testWidgets(
    'returning the finger to its origin restores the cover position',
    (t) async {
      await t.pumpWidget(host());
      final g = await t.startGesture(t.getCenter(find.byKey(page)));
      await g.moveBy(const Offset(0, -20));
      await g.moveBy(const Offset(0, -100));
      await g.moveBy(const Offset(0, 120));
      await t.pump();
      expect(t.getTopLeft(find.byKey(page)).dy, closeTo(0, 0.01));
      await g.cancel();
      await t.pumpAndSettle();
    },
  );

  testWidgets('disposing while dragging does not leave a ticker or callback', (
    t,
  ) async {
    await t.pumpWidget(host());
    final g = await t.startGesture(t.getCenter(find.byKey(page)));
    await g.moveBy(const Offset(0, 20));
    await g.moveBy(const Offset(0, 100));
    await t.pump();
    await t.pumpWidget(const SizedBox.shrink());
    await g.cancel();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets('cancel restores the cover, Reduce Motion=$reduced', (t) async {
      await t.pumpWidget(host(reducedMotion: reduced));
      final g = await t.startGesture(t.getCenter(find.byKey(page)));
      await g.moveBy(const Offset(0, 20));
      await g.moveBy(const Offset(0, 100));
      await t.pump();
      expect(t.getTopLeft(find.byKey(page)).dy, closeTo(120, 0.01));
      await g.cancel();
      await t.pumpAndSettle();
      expect(t.getTopLeft(find.byKey(page)).dy, 0);
    });
  }

  testWidgets('a new drag interrupts the return without a position reset', (
    t,
  ) async {
    await t.pumpWidget(host());
    var g = await t.startGesture(t.getCenter(find.byKey(page)));
    await g.moveBy(const Offset(0, 20));
    await g.moveBy(const Offset(0, 100));
    await t.pump(const Duration(milliseconds: 300));
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    final before = t.getTopLeft(find.byKey(page)).dy;
    g = await t.startGesture(t.getCenter(find.byKey(page)));
    await g.moveBy(const Offset(0, 20));
    await g.moveBy(const Offset(0, 40));
    await t.pump(const Duration(milliseconds: 200));
    expect(t.getTopLeft(find.byKey(page)).dy, closeTo(before + 60, 0.01));
    await g.cancel();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets('disabling an active drag clears its offset before re-enabling', (
    t,
  ) async {
    await t.pumpWidget(host());
    final g = await t.startGesture(t.getCenter(find.byKey(page)));
    await g.moveBy(const Offset(0, 20));
    await g.moveBy(const Offset(0, 100));
    await t.pump();
    await t.pumpWidget(host(enabled: false));
    expect(t.getTopLeft(find.byKey(page)).dy, 0);
    await g.cancel();
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.byKey(page)).dy, 0);
  });

  testWidgets('custom return spring changes the return motion', (t) async {
    Future<double> returnPosition(
      GlassFullScreenCoverDragConfiguration configuration,
    ) async {
      await t.pumpWidget(host(configuration: configuration));
      final g = await t.startGesture(t.getCenter(find.byKey(page)));
      await g.moveBy(const Offset(0, 20));
      await g.moveBy(const Offset(0, 100));
      await t.pump(const Duration(milliseconds: 300));
      await g.up();
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      final y = t.getTopLeft(find.byKey(page)).dy;
      await t.pumpAndSettle();
      return y;
    }

    final normal = await returnPosition(
      const GlassFullScreenCoverDragConfiguration(),
    );
    final slow = await returnPosition(
      const GlassFullScreenCoverDragConfiguration(
        settleSpring: SpringDescription(mass: 1, stiffness: 40, damping: 12),
      ),
    );
    expect(slow, greaterThan(normal + 15));
  });
}
