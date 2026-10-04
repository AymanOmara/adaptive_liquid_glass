import 'dart:math' as math;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/core/shape_border.dart';
import 'package:adaptive_liquid_glass/src/degraded/degraded_glass.dart';
import 'package:adaptive_liquid_glass/src/material/material_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_uniforms.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/texture_space.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void env({bool rt = false, bool shader = true, int? version = 26}) {
  GlassPlatform.instance.debugEnvironment = GlassEnvironment(
    platform: defaultTargetPlatform,
    iosMajorVersion: defaultTargetPlatform == TargetPlatform.iOS
        ? version
        : null,
    reduceTransparency: rt,
    shaderSupported: shader,
  );
}

/// `pumpWidget` provides no MediaQuery under a Directionality-only host, so
/// supply one from the test view (`implicitView` is `tester.view`); the
/// expectations compare against `tester.view.devicePixelRatio`.
Widget host(Widget child) => MediaQuery(
  data: MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.implicitView!,
  ),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

Widget at(Rect r, Widget child) => host(
  Stack(
    children: [Positioned.fromRect(rect: r, child: child)],
  ),
);

RenderGlassBackdrop backdropOf(WidgetTester t, [int index = 0]) => t
    .renderObjectList<RenderGlassBackdrop>(find.byType(GlassBackdrop))
    .elementAt(index);

Rect expected(WidgetTester t, Rect global, GlassBackdropDebugFrame f) =>
    toTextureSpace(
      global,
      filterOriginGlobal: f.filterOriginGlobal,
      devicePixelRatio: t.view.devicePixelRatio,
    );

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('standalone glass draws one shape at its global rect', (t) async {
    env();
    const r = Rect.fromLTWH(20, 40, 100, 50);
    await t.pumpWidget(at(r, const LiquidGlass(child: SizedBox.expand())));
    final f = backdropOf(t).debugLastFrame!;
    final dpr = t.view.devicePixelRatio;
    expect(f.uniforms.shapes.single.rect, expected(t, r, f));
    expect(f.uniforms.shapes.single.radius, 25 * dpr);
    expect(f.localBounds.contains(Offset.zero), isTrue);
  }, variant: ios);

  testWidgets('a GlassGroup draws its members in one pass', (t) async {
    env();
    await t.pumpWidget(
      host(
        const Center(
          child: GlassGroup(
            spacing: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlass(child: SizedBox(width: 50, height: 50)),
                SizedBox(width: 8),
                LiquidGlass(child: SizedBox(width: 50, height: 50)),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(GlassBackdrop), findsOneWidget);
    final f = backdropOf(t).debugLastFrame!;
    expect(f.uniforms.shapes, hasLength(2));
    expect(
      f.uniforms.smoothing,
      GlassConstants.standard.mergeFactor * 10 * t.view.devicePixelRatio,
    );
  }, variant: ios);

  testWidgets('clip margin grows with mergeFactor > 1', (t) async {
    env();
    Widget group(GlassConstants c) => LiquidGlassTheme(
      data: LiquidGlassThemeData(constants: c),
      child: host(
        const Center(
          child: GlassGroup(
            spacing: 10,
            child: LiquidGlass(child: SizedBox(width: 50, height: 50)),
          ),
        ),
      ),
    );
    await t.pumpWidget(group(GlassConstants.standard));
    final base = backdropOf(t).debugLastFrame!.localBounds;
    await t.pumpWidget(group(GlassConstants.fromJson({'mergeFactor': 3.0})));
    final wide = backdropOf(t).debugLastFrame!.localBounds;
    // margin = shadow × 2 + max(1, mergeFactor) × spacing + 2.
    expect(wide.width - base.width, closeTo(2 * (3 - 1) * 10, 1e-6));
    await t.pumpWidget(group(GlassConstants.fromJson({'mergeFactor': 0.5})));
    expect(backdropOf(t).debugLastFrame!.localBounds.width, base.width);
  }, variant: ios);

  testWidgets('capsules and circles use circular corners; rects the fitted '
      'exponent', (t) async {
    env();
    await t.pumpWidget(
      host(
        const Center(
          child: GlassGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlass(child: SizedBox(width: 80, height: 40)),
                LiquidGlass(
                  shape: GlassShape.rect(16),
                  child: SizedBox(width: 80, height: 40),
                ),
                LiquidGlass(
                  shape: GlassShape.circle(),
                  child: SizedBox(width: 40, height: 40),
                ),
                LiquidGlass(
                  shape: GlassShape.concentric(),
                  child: SizedBox(width: 40, height: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final f = backdropOf(t).debugLastFrame!;
    final packed = packGlassUniforms(f.uniforms);
    expect(f.uniforms.shapes.map((s) => s.cornerExponent), [
      2.0,
      null,
      2.0,
      2.0,
    ]);
    expect(
      [for (var i = 0; i < 4; i++) packed[80 + i * 4 + 2]],
      [2.0, GlassConstants.standard.cornerExponent, 2.0, 2.0],
    );
  }, variant: ios);

  testWidgets('concentric inside a container keeps the fitted exponent', (
    t,
  ) async {
    env();
    await t.pumpWidget(
      at(
        const Rect.fromLTWH(0, 0, 200, 100),
        const GlassGroup(
          child: LiquidGlass(
            shape: GlassShape.rect(28),
            child: Padding(
              padding: EdgeInsetsDirectional.all(8),
              child: LiquidGlass(
                shape: GlassShape.concentric(),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    final shapes = backdropOf(t).debugLastFrame!.uniforms.shapes;
    expect(shapes.map((s) => s.cornerExponent), [null, null]);
  }, variant: ios);

  testWidgets('frost blur sigma is the largest of the drawn variants', (
    t,
  ) async {
    env();
    Widget group(Brightness b, List<Glass> glasses) => MediaQuery(
      data: MediaQueryData.fromView(
        WidgetsBinding.instance.platformDispatcher.implicitView!,
      ).copyWith(platformBrightness: b),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: GlassGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final g in glasses)
                  LiquidGlass(
                    glass: g,
                    child: const SizedBox(width: 40, height: 40),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    const c = GlassConstants.standard;
    // 40 x 40 members: half the shorter side is 20 (blurSizeRef scaling).
    double sigma(GlassVariantConstants v) => v.blurSizeRef > 0
        ? v.blurSigma * math.min(1.0, 20 / v.blurSizeRef)
        : v.blurSigma;
    await t.pumpWidget(group(Brightness.light, [Glass.clear]));
    expect(backdropOf(t).debugLastFrame!.blurSigma, sigma(c.clear));
    await t.pumpWidget(group(Brightness.light, [Glass.clear, Glass.regular]));
    expect(
      backdropOf(t).debugLastFrame!.blurSigma,
      math.max(sigma(c.clear), sigma(c.regular)),
    );
    await t.pumpWidget(group(Brightness.dark, [Glass.regular]));
    expect(backdropOf(t).debugLastFrame!.blurSigma, sigma(c.regularDark));
  }, variant: ios);

  testWidgets('frost blur scales down on shapes smaller than blurSizeRef', (
    t,
  ) async {
    env();
    Widget group(GlassConstants c, List<double> sizes) => LiquidGlassTheme(
      data: LiquidGlassThemeData(constants: c),
      child: host(
        Center(
          child: GlassGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in sizes)
                  LiquidGlass(
                    child: SizedBox(width: s * 2, height: s),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final c = GlassConstants.fromJson({
      'regular': {'blurSigma': 6.0, 'blurSizeRef': 40.0},
    });
    // Half the shorter side 10 -> sigma 6 x 10 / 40.
    await t.pumpWidget(group(c, [20]));
    expect(backdropOf(t).debugLastFrame!.blurSigma, closeTo(1.5, 1e-9));
    // The group blurs with the largest member's sigma (half side 50 -> 6).
    await t.pumpWidget(group(c, [20, 100]));
    expect(backdropOf(t).debugLastFrame!.blurSigma, closeTo(6.0, 1e-9));
    // blurSizeRef 0 disables the scaling.
    final off = GlassConstants.fromJson({
      'regular': {'blurSigma': 6.0, 'blurSizeRef': 0.0},
    });
    await t.pumpWidget(group(off, [20]));
    expect(backdropOf(t).debugLastFrame!.blurSigma, 6.0);
  }, variant: ios);

  testWidgets('zero-size glass is skipped without errors', (t) async {
    env();
    await t.pumpWidget(at(Rect.zero, const LiquidGlass(child: SizedBox())));
    expect(backdropOf(t).debugLastFrame, isNull);
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('child renders while the shader is still loading', (t) async {
    env();
    await t.pumpWidget(
      at(
        const Rect.fromLTWH(0, 0, 100, 40),
        const LiquidGlass(child: Text('hi', textDirection: TextDirection.ltr)),
      ),
    );
    expect(find.text('hi'), findsOneWidget);
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('glass inside a scrolled list tracks its position', (t) async {
    env();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      host(
        ListView(
          controller: controller,
          children: [
            for (var i = 0; i < 20; i++)
              SizedBox(
                height: 100,
                child: i == 3
                    ? const LiquidGlass(
                        key: ValueKey('g'),
                        child: SizedBox.expand(),
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
    // Settle the group's post-frame rebuild so only the scroll repaints.
    await t.pump();
    controller.jumpTo(50);
    await t.pump();
    final f = backdropOf(t).debugLastFrame!;
    final global = t.getRect(find.byKey(const ValueKey('g')));
    expect(global.top, 250);
    expect(f.uniforms.shapes.single.rect, expected(t, global, f));
  }, variant: ios);

  for (final axis in Axis.values) {
    testWidgets('glass scrolling inside its own group tracks its position '
        '(${axis.name})', (t) async {
      env();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await t.pumpWidget(
        host(
          GlassGroup(
            // The viewport is a repaint boundary: scrolling repaints it, not
            // the group's backdrop.
            child: ListView(
              controller: controller,
              scrollDirection: axis,
              children: [
                for (var i = 0; i < 20; i++)
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: i == 3
                        ? const LiquidGlass(
                            key: ValueKey('g'),
                            child: SizedBox.expand(),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ),
      );
      // Let the group's post-frame `settled` rebuild happen first, so the
      // only change in the next frame is the scroll.
      await t.pump();
      final before = backdropOf(t).debugLastFrame!;
      controller.jumpTo(50);
      await t.pump();
      final f = backdropOf(t).debugLastFrame!;
      final global = t.getRect(find.byKey(const ValueKey('g')));
      expect(axis == Axis.vertical ? global.top : global.left, 250);
      expect(f, isNot(same(before)));
      expect(f.uniforms.shapes.single.rect, expected(t, global, f));
    }, variant: ios);
  }

  testWidgets('glass tracks a route transition', (t) async {
    env();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(CupertinoApp(navigatorKey: nav, home: const SizedBox()));
    nav.currentState!.push(
      CupertinoPageRoute<void>(
        builder: (_) => const Center(
          child: LiquidGlass(
            key: ValueKey('g'),
            child: SizedBox(width: 80, height: 40),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 150));
    final f = backdropOf(t).debugLastFrame!;
    final global = t.getRect(find.byKey(const ValueKey('g')));
    expect(
      f.uniforms.shapes.single.rect.left,
      closeTo(expected(t, global, f).left, 0.5),
    );
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('Android renders Material', (t) async {
    env();
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: LiquidGlass(child: SizedBox(width: 80, height: 40)),
          ),
        ),
      ),
    );
    expect(find.byType(MaterialGlass), findsOneWidget);
    expect(find.byType(GlassBackdrop), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Reduce Transparency switches to opaque while running', (
    t,
  ) async {
    env();
    await t.pumpWidget(
      at(
        const Rect.fromLTWH(0, 0, 100, 40),
        const LiquidGlass(child: SizedBox.expand()),
      ),
    );
    expect(backdropOf(t).debugLastFrame!.uniforms.opaqueColor, isNull);
    env(rt: true);
    await t.pump();
    expect(
      backdropOf(t).debugLastFrame!.uniforms.opaqueColor,
      opaqueGlassColor(Brightness.light),
    );
  }, variant: ios);

  testWidgets('no shader support uses the degraded renderer', (t) async {
    env(shader: false);
    await t.pumpWidget(
      at(
        const Rect.fromLTWH(0, 0, 100, 40),
        const LiquidGlass(child: SizedBox.expand()),
      ),
    );
    expect(find.byType(DegradedGlass), findsOneWidget);
  }, variant: ios);

  testWidgets('the 17th member renders in its own group', (t) async {
    env();
    await t.pumpWidget(
      host(
        GlassGroup(
          child: Wrap(
            children: [
              for (var i = 0; i < 17; i++)
                const LiquidGlass(child: SizedBox(width: 20, height: 20)),
            ],
          ),
        ),
      ),
    );
    expect(t.takeException(), isFlutterError);
    expect(find.byType(GlassBackdrop), findsNWidgets(2));
    expect(backdropOf(t, 0).debugLastFrame!.uniforms.shapes, hasLength(16));
    expect(backdropOf(t, 1).debugLastFrame!.uniforms.shapes, hasLength(1));
  }, variant: ios);

  testWidgets('concentric child radius = container radius − inset', (t) async {
    env();
    await t.pumpWidget(
      at(
        const Rect.fromLTWH(0, 0, 200, 100),
        const GlassGroup(
          child: LiquidGlass(
            shape: GlassShape.rect(28),
            child: Padding(
              padding: EdgeInsetsDirectional.all(8),
              child: LiquidGlass(
                shape: GlassShape.concentric(),
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    final shapes = backdropOf(t).debugLastFrame!.uniforms.shapes;
    expect(shapes[1].radius, 20 * t.view.devicePixelRatio);
  }, variant: ios);

  testWidgets('unionId merges members into one shape', (t) async {
    env();
    await t.pumpWidget(
      host(
        const Center(
          child: GlassGroup(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlass(
                  unionId: 'a',
                  child: SizedBox(width: 40, height: 40),
                ),
                SizedBox(width: 60),
                LiquidGlass(
                  unionId: 'a',
                  child: SizedBox(width: 40, height: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(backdropOf(t).debugLastFrame!.uniforms.shapes, hasLength(1));
  }, variant: ios);

  testWidgets('pressing interactive glass grows the shape and glows', (
    t,
  ) async {
    env();
    const r = Rect.fromLTWH(100, 100, 120, 40);
    await t.pumpWidget(
      at(
        r,
        LiquidGlass(
          glass: Glass.regular.interactive(),
          child: const SizedBox.expand(),
        ),
      ),
    );
    final before = backdropOf(t).debugLastFrame!.uniforms.shapes.single.rect;
    final gesture = await t.startGesture(r.centerRight - const Offset(4, 0));
    await t.pump(); // the spring's ticker starts on the first frame
    await t.pump(const Duration(milliseconds: 400));
    final pressed = backdropOf(t).debugLastFrame!.uniforms;
    expect(pressed.shapes.single.rect.width, greaterThan(before.width));
    expect(pressed.glow, greaterThan(0.5));
    expect(pressed.touch, isNotNull);
    await gesture.up();
    await t.pumpAndSettle();
    final after = backdropOf(t).debugLastFrame!.uniforms;
    expect(after.shapes.single.rect, before);
    expect(after.glow, 0);
  }, variant: ios);

  testWidgets('non-interactive glass ignores presses', (t) async {
    env();
    const r = Rect.fromLTWH(100, 100, 120, 40);
    await t.pumpWidget(at(r, const LiquidGlass(child: SizedBox.expand())));
    final before = backdropOf(t).debugLastFrame!.uniforms.shapes.single.rect;
    final gesture = await t.startGesture(r.center);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(backdropOf(t).debugLastFrame!.uniforms.shapes.single.rect, before);
    await gesture.up();
  }, variant: ios);
}
