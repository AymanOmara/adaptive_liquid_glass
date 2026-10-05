import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/lens_rim.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('lensEndShade', () {
    test('an end well inside the bar refracts the bar: no dark band', () {
      expect(lensEndShade(inside: 20), 0);
    });
    test('an end at or past the bar edge refracts what is outside: dark', () {
      expect(lensEndShade(inside: 0), 1);
      expect(lensEndShade(inside: -8), 1);
    });
    test('up to 2 pt inside it is still fully dark, then fades', () {
      expect(lensEndShade(inside: 2), 1);
      expect(lensEndShade(inside: 5), closeTo(0.5, 0.01));
      expect(lensEndShade(inside: 8), 0);
    });
  });

  testWidgets('a held lens draws its rim; the pill at rest does not', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassTabBar(
          items: const [
            GlassTabBarItem(icon: CupertinoIcons.clock, label: 'A'),
            GlassTabBarItem(icon: CupertinoIcons.gear, label: 'B'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ),
    );
    Finder rim() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is LensRimPainter,
    );
    expect(rim(), findsNothing);
    final g = await t.startGesture(t.getCenter(find.text('A')));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(rim(), findsOneWidget);
    final painter = t.widget<CustomPaint>(rim()).painter! as LensRimPainter;
    expect(painter.strength, closeTo(1, 0.05));
    // The first tab's lens reaches past the bar's leading end.
    expect(painter.leftShade, 1);
    expect(painter.rightShade, 0);
    await g.up();
    await t.pumpAndSettle();
    expect(rim(), findsNothing);
  }, variant: ios);
}
