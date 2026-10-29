import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/layer/glass_layer.dart';
import 'package:adaptive_liquid_glass/src/layer/glass_layer_slot.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _button(String text) => LiquidGlass(
  child: SizedBox(width: 100, height: 40, child: Center(child: Text(text))),
);

List<RenderGlassBackdrop> _backdrops(WidgetTester t) => t
    .renderObjectList<RenderGlassBackdrop>(
      find.byType(GlassBackdrop, skipOffstage: false),
    )
    .toList();

void main() {
  setUp(() {
    GlassProgram.instance.debugReset(skipLoad: true);
    GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
      platform: TargetPlatform.android,
      iosMajorVersion: null,
      reduceTransparency: false,
      shaderSupported: true,
    );
  });
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a local layer shares one slot without needing a route', (
    t,
  ) async {
    await t.pumpWidget(
      LiquidGlassTheme(
        data: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: GlassLayerScope(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [_button('a'), _button('b')],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final boxes = _backdrops(t);
    final layer = boxes.first.sharedLayer!;
    expect(boxes.map((box) => box.sharedLayer), everyElement(same(layer)));
    expect(find.byType(GlassLayerSlot), findsOneWidget);
    expect(layer.debugLastPlan!.single.passes, hasLength(1));
    expect(t.getSize(find.byType(GlassLayerScope)), const Size(100, 80));
  });

  testWidgets('local layer follows an ancestor transform without rebuilding', (
    t,
  ) async {
    final position = ValueNotifier<Offset>(Offset.zero);
    addTearDown(position.dispose);
    await t.pumpWidget(
      LiquidGlassTheme(
        data: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
        child: MaterialApp(
          home: Center(
            child: ValueListenableBuilder<Offset>(
              valueListenable: position,
              builder: (_, offset, child) =>
                  Transform.translate(offset: offset, child: child),
              child: GlassLayerScope(child: _button('moving')),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final layer = _backdrops(t).single.sharedLayer!;
    Rect bounds() => layer.debugLastPlan!.single.passes.single.bounds;
    final before = bounds();
    position.value = const Offset(30, 20);
    await t.pump();
    expect(bounds(), before.shift(position.value));
    await t.pumpAndSettle();
  });

  testWidgets('an explicit opt-out inside a local scope is respected', (
    t,
  ) async {
    await t.pumpWidget(
      LiquidGlassTheme(
        data: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
        child: MaterialApp(
          home: GlassLayerScope(
            child: Column(
              children: [
                _button('shared'),
                GlassLayerOptOut(child: _button('in place')),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final boxes = _backdrops(t);
    expect(boxes.first.sharedLayer, isNotNull);
    expect(boxes.last.sharedLayer, isNull);
  });

  for (final snapshotting in [true, false]) {
    testWidgets('route scope stays shared during zoom ($snapshotting)', (
      t,
    ) async {
      final nav = GlobalKey<NavigatorState>();
      Widget page(String label) {
        final content = Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_button('$label 1'), _button('$label 2')],
          ),
        );
        // The package scaffold installs the scope automatically; a plain
        // Flutter scaffold can opt in explicitly.
        return snapshotting
            ? GlassLayerScope(child: Scaffold(body: content))
            : GlassScaffold(sampleBackdrop: false, body: content);
      }

      await t.pumpWidget(
        LiquidGlassTheme(
          data: const LiquidGlassThemeData(
            defaultMode: GlassRenderMode.shader,
            androidShaderBudget: 0,
          ),
          child: MaterialApp(
            navigatorKey: nav,
            theme: ThemeData(
              platform: TargetPlatform.android,
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: ZoomPageTransitionsBuilder(
                    allowSnapshotting: snapshotting,
                  ),
                },
              ),
            ),
            home: page('a'),
          ),
        ),
      );
      await t.pumpAndSettle();
      final originalLayer = _backdrops(t).first.sharedLayer!;
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => page('b')),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      final mid = _backdrops(t);
      expect(mid, hasLength(4));
      expect(mid.map((box) => box.sharedLayer), everyElement(isNotNull));
      expect(mid.first.sharedLayer, same(originalLayer));
      expect(mid[2].sharedLayer, isNot(same(originalLayer)));
      expect(
        find.byType(GlassLayerSlot, skipOffstage: false),
        findsNWidgets(2),
      );
      await t.pumpAndSettle();
      nav.currentState!.pop();
      await t.pumpAndSettle();
      expect(_backdrops(t).first.sharedLayer, same(originalLayer));
    });
  }

  testWidgets('menu glass batches inside its follower and remains tappable', (
    t,
  ) async {
    var selected = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: GlassMenuButton(
              mode: GlassRenderMode.shader,
              semanticLabel: 'More',
              icon: Icons.more_horiz,
              items: [
                GlassMenuItem(
                  label: 'Choose',
                  onSelected: () => selected = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.tap(find.bySemanticsLabel('More'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    final menu = _backdrops(t).single;
    expect(menu.sharedLayer, isNotNull);
    expect(menu.sharedLayer!.clients, [menu]);
    // The opening opacity is inherited by both glass and contents, rather
    // than applied a second time to each deferred group.
    expect(
      menu
          .sharedLayer!
          .debugLastPlan!
          .single
          .passes
          .single
          .uniforms
          .shapes
          .single
          .opacity,
      1,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Choose'));
    await t.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('Choose'), findsNothing);
  });
}
