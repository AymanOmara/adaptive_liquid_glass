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

  test('the tab lens bends smoothly, fringes in blue and has no frost', () {
    for (final c in [tabLensLight, tabLensDark]) {
      expect(c.blurSigma, 0);
      expect(c.frostWideSigma, 0);
      expect(c.postBlurShare, 0);
      // A continuous inward lens: no ring, whose ends break the image.
      expect(c.lensStrength, lessThan(0));
      expect(c.lensRingEnd, lessThanOrEqualTo(c.lensRingStart));
      // Negative: green moves with blue, so blue fringes stay blue.
      expect(c.dispersion, lessThan(0));
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
    // UIKit's bar is flat dark glass with an even rim (Kept over black).
    final barTheme = LiquidGlassTheme.of(t.element(find.byWidget(barGlass)));
    for (final v in [
      barTheme.constants.regular,
      barTheme.constants.regularDark,
    ]) {
      expect(v.toneLift, 0);
      expect(v.rimIntensity, 0);
      expect(v.rimMix, greaterThan(0));
    }
    await g.up();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('the lens magnifies each tab about its own centre', (t) async {
    // iOS keeps a tab at the lens's rim in view; magnifying about the lens
    // centre would push it out past the rim.
    env(ios: 26);
    await t.pumpWidget(bar());
    final g = await hold(t);
    final xs = find
        .text('Settings')
        .evaluate()
        .map((e) => t.getCenter(find.byElementPredicate((x) => x == e)).dx)
        .toList();
    expect(xs.length, 2, reason: 'the tab and its copy under the lens');
    expect(xs[0], closeTo(xs[1], 0.5));
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
