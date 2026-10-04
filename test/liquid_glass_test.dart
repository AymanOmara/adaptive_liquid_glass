import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/core/shape_border.dart';
import 'package:adaptive_liquid_glass/src/degraded/degraded_glass.dart';
import 'package:adaptive_liquid_glass/src/material/material_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/texture_space.dart';
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
    expect(f.uniforms.smoothing, 2 * 10 * t.view.devicePixelRatio);
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
    controller.jumpTo(50);
    await t.pump();
    final f = backdropOf(t).debugLastFrame!;
    final global = t.getRect(find.byKey(const ValueKey('g')));
    expect(global.top, 250);
    expect(f.uniforms.shapes.single.rect, expected(t, global, f));
  }, variant: ios);

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
}
