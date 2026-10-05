import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/tab_lens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void env({required int ios, bool shader = true}) {
  GlassPlatform.instance.debugEnvironment = GlassEnvironment(
    platform: TargetPlatform.iOS,
    iosMajorVersion: ios,
    reduceTransparency: false,
    shaderSupported: shader,
  );
}

Widget bar() => plainHost(
  GlassTabBar(
    items: const [
      GlassTabBarItem(icon: CupertinoIcons.clock, label: 'History'),
      GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
    ],
    selectedIndex: 0,
    onSelected: (_) {},
  ),
);

Finder get lens =>
    find.byWidgetPredicate((w) => w is LiquidGlass && w.glass == Glass.clear);

Future<TestGesture> hold(WidgetTester t) async {
  final g = await t.startGesture(t.getCenter(find.text('History')));
  for (var i = 0; i < 20; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
  return g;
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  test('the tab lens refracts outward, with dispersion and no frost', () {
    for (final c in [tabLensLight, tabLensDark]) {
      expect(c.blurSigma, 0);
      expect(c.frostWideSigma, 0);
      expect(c.postBlurShare, 0);
      expect(c.lensRingEnd, greaterThan(c.lensRingStart));
      expect(c.lensRingReach, greaterThan(0), reason: 'samples outward');
      expect(c.dispersion, greaterThan(0));
    }
  });

  testWidgets('on iOS 26 the lens is shader glass over the native bar', (
    t,
  ) async {
    env(ios: 26);
    await t.pumpWidget(bar());
    final g = await hold(t);
    expect(t.widget<LiquidGlass>(lens).mode, GlassRenderMode.shader);
    final theme = LiquidGlassTheme.of(t.element(lens));
    expect(theme.constants.clear, tabLensLight);
    expect(theme.constants.clearDark, tabLensDark);
    // The bar is shader glass too, so the lens can refract it (native glass
    // is invisible to the shader).
    final barGlass = t
        .widgetList<LiquidGlass>(find.byType(LiquidGlass))
        .firstWhere((w) => w.glass != Glass.clear);
    expect(barGlass.mode, GlassRenderMode.shader);
    await g.up();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('an explicit mode wins for the bar', (t) async {
    env(ios: 26);
    await t.pumpWidget(
      plainHost(
        GlassTabBar(
          mode: GlassRenderMode.native,
          items: const [
            GlassTabBarItem(icon: CupertinoIcons.clock, label: 'History'),
            GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
      ),
    );
    final barGlass = t
        .widgetList<LiquidGlass>(find.byType(LiquidGlass))
        .firstWhere((w) => w.glass != Glass.clear);
    expect(barGlass.mode, GlassRenderMode.native);
  }, variant: ios);

  testWidgets('the shader lens bends a full copy; no sharp overlay needed', (
    t,
  ) async {
    env(ios: 26);
    await t.pumpWidget(bar());
    final g = await hold(t);
    expect(
      find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper.runtimeType.toString() == '_LensEnds',
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(GlassTabBar),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );
    await g.up();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('without shader support the lens keeps the native approach', (
    t,
  ) async {
    env(ios: 26, shader: false);
    await t.pumpWidget(bar());
    final g = await hold(t);
    expect(t.widget<LiquidGlass>(lens).mode, isNull);
    expect(
      find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper.runtimeType.toString() == '_LensEnds',
      ),
      findsOneWidget,
    );
    await g.up();
    await t.pumpAndSettle();
  }, variant: ios);
}
