import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/layer/glass_layer.dart';
import 'package:adaptive_liquid_glass/src/layer/glass_layer_anchor.dart';
import 'package:adaptive_liquid_glass/src/layer/glass_layer_slot.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/render_vibrant_blend.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/vibrant_blend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void env() {
  GlassPlatform.instance.debugEnvironment = GlassEnvironment(
    platform: defaultTargetPlatform,
    iosMajorVersion: null,
    reduceTransparency: false,
    shaderSupported: true,
  );
}

Widget app(Widget home) => LiquidGlassTheme(
  data: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
  child: MaterialApp(home: home),
);

Widget button(String label) => LiquidGlass(
  child: SizedBox(width: 80, height: 40, child: Center(child: Text(label))),
);

List<RenderGlassBackdrop> backdrops(WidgetTester t) => t
    .renderObjectList<RenderGlassBackdrop>(find.byType(GlassBackdrop))
    .toList();

final android = TargetPlatformVariant.only(TargetPlatform.android);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() {
    GlassPlatform.instance.debugReset();
    GlassSharedLayer.debugEnabled = null;
  });

  testWidgets('groups of one route share one layer and one pass', (t) async {
    env();
    await t.pumpWidget(
      app(
        Scaffold(
          body: Column(
            children: [
              button('a'),
              const SizedBox(height: 40),
              button('b'),
              const SizedBox(height: 40),
              button('c'),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    final bs = backdrops(t);
    expect(bs, hasLength(3));
    final layer = bs.first.sharedLayer!;
    expect(bs.map((b) => b.sharedLayer), everyElement(same(layer)));
    final plan = layer.debugLastPlan!;
    expect(plan, hasLength(1));
    expect(plan.single.passes, hasLength(1));
    expect(plan.single.passes.single.uniforms.shapes, hasLength(3));
    expect(plan.single.passes.single.uniforms.shapes.map((s) => s.group), [
      0,
      1,
      2,
    ]);
    // Exactly one slot paints.
    final slots = t.renderObjectList<RenderGlassLayerSlot>(
      find.byType(GlassLayerSlot),
    );
    expect(slots, hasLength(3));
    expect(slots.where((s) => identical(layer.painter, s)), hasLength(1));
  }, variant: android);

  testWidgets('the content composites after the pass in the slot', (t) async {
    env();
    await t.pumpWidget(app(Scaffold(body: Center(child: button('a')))));
    await t.pump();
    final b = backdrops(t).single;
    final slot = b.sharedLayer!.painter!;
    // The group's content layer now hangs under the painting slot.
    final contentLayer = b.child!.debugLayer!;
    Layer? p = contentLayer;
    while (p != null && !identical(p, slot.debugLayer)) {
      p = p.parent;
    }
    expect(p, same(slot.debugLayer));
    // The backdrop itself pushes nothing in place.
    expect(b.debugLayer, isNull);
  }, variant: android);

  testWidgets('a rounded clip around glass clips the pass and content', (
    t,
  ) async {
    env();
    await t.pumpWidget(
      app(
        Scaffold(
          body: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: button('a'),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    final b = backdrops(t).single;
    final box = t.getRect(find.byType(ClipRRect));
    final inside = box.center;
    final corner = box.topLeft + const Offset(1, 1);
    // The pass (not drawn without the shader in tests) is planned shaped.
    final pass = b.sharedLayer!.debugLastPlan!.single.passes.single;
    expect(pass.clipPath!.contains(inside), isTrue);
    expect(pass.clipPath!.contains(corner), isFalse);
    // The group's content composites under the same rounded clip.
    final clip = b.sharedLayer!.painter!.debugLayer!.firstChild;
    expect(clip, isA<ClipPathLayer>());
    final path = (clip! as ClipPathLayer).clipPath!;
    expect(path.contains(inside), isTrue);
    expect(path.contains(corner), isFalse);
  }, variant: android);

  testWidgets('a dialog route gets its own layer', (t) async {
    env();
    await t.pumpWidget(app(Scaffold(body: Center(child: button('page')))));
    final ctx = t.element(find.text('page'));
    showDialog<void>(
      context: ctx,
      builder: (_) => Center(child: button('dialog')),
    );
    await t.pumpAndSettle();
    final bs = backdrops(t);
    expect(bs, hasLength(2));
    expect(bs[0].sharedLayer, isNotNull);
    expect(bs[1].sharedLayer, isNotNull);
    expect(identical(bs[0].sharedLayer, bs[1].sharedLayer), isFalse);
  }, variant: android);

  testWidgets('glass over glass draws in a later stratum', (t) async {
    env();
    await t.pumpWidget(
      app(
        Scaffold(
          body: Stack(
            children: [
              Positioned(left: 0, top: 0, child: button('under')),
              Positioned(left: 20, top: 10, child: button('over')),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    final plan = backdrops(t).first.sharedLayer!.debugLastPlan!;
    expect(plan, hasLength(2));
  }, variant: android);

  testWidgets('shared glass takes no budget ticket', (t) async {
    env();
    await t.pumpWidget(
      LiquidGlassTheme(
        data: const LiquidGlassThemeData(
          defaultMode: GlassRenderMode.shader,
          androidShaderBudget: 1,
        ),
        child: MaterialApp(
          home: Scaffold(
            body: Column(children: [button('a'), button('b'), button('c')]),
          ),
        ),
      ),
    );
    expect(backdrops(t), hasLength(3));
    expect(backdrops(t).map((b) => b.sharedLayer), everyElement(isNotNull));
  }, variant: android);

  testWidgets('switch off: each group draws its own glass', (t) async {
    env();
    GlassSharedLayer.debugEnabled = false;
    await t.pumpWidget(app(Scaffold(body: Center(child: button('a')))));
    final b = backdrops(t).single;
    expect(b.sharedLayer, isNull);
    expect(b.debugLastFrame, isNotNull);
  }, variant: android);

  testWidgets('iOS keeps the per-group path by default', (t) async {
    env();
    await t.pumpWidget(app(Scaffold(body: Center(child: button('a')))));
    expect(backdrops(t).single.sharedLayer, isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('no route: per-group path', (t) async {
    env();
    await t.pumpWidget(
      LiquidGlassTheme(
        data: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: button('a')),
          ),
        ),
      ),
    );
    expect(backdrops(t).single.sharedLayer, isNull);
  }, variant: android);

  testWidgets('scrolling clips glass to the viewport and repaints', (t) async {
    env();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await t.pumpWidget(
      app(
        Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 100),
              SizedBox(
                height: 200,
                child: ListView(
                  controller: controller,
                  children: [
                    for (var i = 0; i < 10; i++)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: button('$i'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    final layer = backdrops(t).first.sharedLayer!;
    final dpr = t.view.devicePixelRatio;
    final before = layer.debugLastPlan!.first.passes.first.uniforms.shapes;
    expect(
      before.first.clip,
      Rect.fromLTWH(0, 100 * dpr, 800 * dpr, 200 * dpr),
    );
    final top0 = before.first.rect.top;
    controller.jumpTo(10);
    await t.pump();
    final after = layer.debugLastPlan!.first.passes.first.uniforms.shapes;
    expect(after.first.rect.top, closeTo(top0 - 10 * dpr, 1e-6));
  }, variant: android);

  for (final p in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('vibrancy stays on in content deferred to the layer ($p)', (
      t,
    ) async {
      env();
      await t.pumpWidget(
        app(
          const Scaffold(
            body: GlassLayerContent(
              enabled: true,
              child: VibrantBlend(child: Text('label')),
            ),
          ),
        ),
      );
      final blend = t.renderObject<RenderVibrantBlend>(
        find.byType(VibrantBlend),
      );
      // Its backdrop filter, composited by the slot after the glass, reads
      // the glass as it does in place.
      expect(blend.enabled, isTrue);
    }, variant: TargetPlatformVariant.only(p));
  }

  testWidgets('a route covered by an opaque route stops painting its layer', (
    t,
  ) async {
    env();
    await t.pumpWidget(app(Scaffold(body: Center(child: button('page')))));
    await t.pump();
    final layer = backdrops(t).single.sharedLayer!;
    final slot = layer.painter!;
    bool inScene(RenderObject r) {
      Layer? l = r.debugLayer;
      while (l != null && l.parent != null) {
        l = l.parent;
      }
      return l != null && l.attached;
    }

    expect(inScene(slot), isTrue);
    Navigator.of(t.element(find.text('page'))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('top')),
      ),
    );
    await t.pumpAndSettle();
    // The covered page is offstage: its slot's backdrop layers leave the
    // scene, so the engine frees their render targets.
    expect(find.text('page', skipOffstage: false), findsOneWidget);
    expect(inScene(slot), isFalse);
    Navigator.of(t.element(find.text('top'))).pop();
    await t.pumpAndSettle();
    expect(inScene(layer.painter!), isTrue);
  }, variant: android);

  // The sheet's glass is a sibling behind its content: on the layer the
  // glass draws after the route, so the content must be deferred too or
  // it ends up blurred beneath it.
  testWidgets('a glass sheet\'s content draws over its glass', (t) async {
    env();
    await t.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: GestureDetector(
                onTap: () => showGlassSheet<void>(
                  context: context,
                  builder: (_) => const SizedBox(
                    height: 200,
                    child: Center(child: Text('inside')),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    final text = t.renderObject(find.text('inside'));
    RenderGlassBackdrop? deferred;
    for (RenderObject? p = text.parent; p != null; p = p.parent) {
      if (p is RenderGlassBackdrop) {
        deferred = p;
        break;
      }
    }
    expect(deferred?.sharedLayer, isNotNull);
    final layer = deferred!.sharedLayer!;
    final glass = backdrops(
      t,
    ).firstWhere((b) => b != deferred && identical(b.sharedLayer, layer));
    // Content composites with or after the glass's stratum, glass first.
    final plan = layer.debugLastPlan!;
    int stratumOf(Object id) => plan.indexWhere((s) => s.groups.contains(id));
    expect(stratumOf(glass), isNonNegative);
    expect(stratumOf(deferred), greaterThanOrEqualTo(stratumOf(glass)));
  }, variant: android);

  testWidgets('glass under a zoom transition snapshot draws in place', (
    t,
  ) async {
    env();
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      LiquidGlassTheme(
        data: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
        child: MaterialApp(
          navigatorKey: nav,
          theme: ThemeData(
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
            ),
          ),
          home: Scaffold(body: Center(child: button('a'))),
        ),
      ),
    );
    await t.pump();
    expect(backdrops(t).single.sharedLayer, isNotNull);

    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: Center(child: button('b'))),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    // Both pages are snapshotted mid-transition: the layer, painted after
    // the route, would draw their glass outside the zoomed snapshot.
    final mid = t
        .renderObjectList<RenderGlassBackdrop>(
          find.byType(GlassBackdrop, skipOffstage: false),
        )
        .toList();
    expect(mid, hasLength(2));
    expect(mid.map((b) => b.sharedLayer), everyElement(isNull));

    await t.pumpAndSettle();
    final settled = t
        .renderObjectList<RenderGlassBackdrop>(
          find.byType(GlassBackdrop, skipOffstage: false),
        )
        .toList();
    expect(settled.map((b) => b.sharedLayer), everyElement(isNotNull));
  }, variant: android);
}
