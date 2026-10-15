import 'dart:math' as math;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/group/glass_registry.dart';
import 'package:adaptive_liquid_glass/src/native/native_glass_layer.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'native_glass_layer_test.dart' show host, iosEnv, mockNative;

const LiquidGlassThemeData _batching = LiquidGlassThemeData(
  batchImplicitGroups: true,
);

Widget _chip(int i) => GlassChip(label: 'Tag $i', onSelected: (_) {});

Widget _chips(int n) => Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [for (var i = 0; i < n; i++) _chip(i)],
);

/// The shapes of the last payload sent to any view.
List<Map<Object?, Object?>> _shapes(List<Map<Object?, Object?>> sent) => [
  for (final s in sent.last['shapes']! as List) s as Map<Object?, Object?>,
];

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump();
  }

  testWidgets('29 ungrouped chips: 29 native views by default', (t) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(host(Align(child: _chips(29))));
    await settle(t);
    expect(find.byType(UiKitView), findsNWidgets(29));
  }, variant: ios);

  testWidgets('29 chips in a GlassBatch: one native view', (t) async {
    iosEnv();
    final sent = mockNative(t);
    await t.pumpWidget(host(Align(child: GlassBatch(child: _chips(29)))));
    await settle(t);
    expect(find.byType(UiKitView), findsOneWidget);
    expect(NativeGlassLayer.debugLiveCount, 1);
    expect(sent.last['spacing'], 0.0);
    final shapes = _shapes(sent);
    expect(shapes, hasLength(29));
    expect(shapes.map((s) => s['id']).toSet(), hasLength(29));
    expect(shapes.every((s) => !s.containsKey('opacity')), isTrue);
  }, variant: ios);

  testWidgets('batched shapes are local to the batch view', (t) async {
    iosEnv();
    final sent = mockNative(t);
    await t.pumpWidget(
      host(
        const Align(
          alignment: AlignmentDirectional.topStart,
          child: GlassBatch(
            child: Padding(
              padding: EdgeInsets.only(left: 10, top: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidGlass(child: SizedBox(width: 50, height: 30)),
                  SizedBox(width: 12),
                  LiquidGlass(child: SizedBox(width: 40, height: 30)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await settle(t);
    final shapes = _shapes(sent);
    expect(
      [for (final s in shapes) s['x']],
      [10 + kNativeOverhang, 72 + kNativeOverhang],
    );
    expect([
      for (final s in shapes) s['y'],
    ], everyElement(20 + kNativeOverhang));
    expect([for (final s in shapes) s['w']], [50.0, 40.0]);
  }, variant: ios);

  testWidgets('the batch view goes when the last glass does', (t) async {
    iosEnv();
    mockNative(t);
    Widget app(int n) => host(Align(child: GlassBatch(child: _chips(n))));
    await t.pumpWidget(app(3));
    await settle(t);
    expect(find.byType(UiKitView), findsOneWidget);
    await t.pumpWidget(app(0));
    await settle(t);
    expect(find.byType(UiKitView), findsNothing);
    await t.pumpWidget(app(2));
    await settle(t);
    expect(find.byType(UiKitView), findsOneWidget);
  }, variant: ios);

  testWidgets('a batch keeps the content mounted as glass comes and goes', (
    t,
  ) async {
    iosEnv();
    mockNative(t);
    final key = GlobalKey();
    Widget app({required bool glass}) => host(
      Align(
        child: GlassBatch(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(key: key, width: 10, height: 10),
              if (glass) _chip(0),
            ],
          ),
        ),
      ),
    );
    await t.pumpWidget(app(glass: false));
    final element = key.currentContext;
    await t.pumpWidget(app(glass: true));
    await settle(t);
    expect(find.byType(UiKitView), findsOneWidget);
    expect(identical(key.currentContext, element), isTrue);
  }, variant: ios);

  testWidgets('explicit groups inside a batch keep their own view', (t) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(
      host(
        Align(
          child: GlassBatch(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chips(5),
                const GlassGroup(
                  child: LiquidGlass(child: SizedBox(width: 40, height: 40)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(t);
    expect(find.byType(UiKitView), findsNWidgets(2));
  }, variant: ios);

  testWidgets('the theme flag batches a sheet\'s content', (t) async {
    iosEnv();
    mockNative(t);
    Widget app({required bool batch}) => host(
      LiquidGlassTheme(
        data: LiquidGlassThemeData(batchImplicitGroups: batch),
        child: Align(child: GlassSheet(child: _chips(29))),
      ),
    );
    await t.pumpWidget(app(batch: false));
    await settle(t);
    // The sheet's own glass and one view per chip.
    expect(find.byType(UiKitView), findsNWidgets(30));
    await t.pumpWidget(host(const SizedBox()));
    await t.pumpWidget(app(batch: true));
    await settle(t);
    expect(find.byType(UiKitView), findsNWidgets(2));
  }, variant: ios);

  testWidgets('the theme flag batches a GlassScaffold body', (t) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(
      LiquidGlassTheme(
        data: _batching,
        child: MaterialApp(
          home: GlassScaffold(
            sampleBackdrop: false,
            body: Center(child: _chips(12)),
          ),
        ),
      ),
    );
    await settle(t);
    expect(find.byType(UiKitView), findsOneWidget);
  }, variant: ios);

  testWidgets('the theme flag lifts the 16-shape cap of native groups', (
    t,
  ) async {
    iosEnv();
    final sent = mockNative(t);
    Widget app(LiquidGlassThemeData data) => host(
      LiquidGlassTheme(
        data: data,
        child: Align(child: GlassGroup(child: _chips(25))),
      ),
    );
    // Past the cap the registry reports a non-fatal error per member.
    final errors = <FlutterErrorDetails>[];
    final saved = FlutterError.onError;
    FlutterError.onError = errors.add;
    await t.pumpWidget(app(const LiquidGlassThemeData()));
    await settle(t);
    FlutterError.onError = saved;
    expect(errors, hasLength(25 - GlassRegistry.maxShapes));
    // Members past the 16th each get a group (and a view) of their own.
    expect(
      find.byType(UiKitView),
      findsNWidgets(1 + 25 - GlassRegistry.maxShapes),
    );

    await t.pumpWidget(host(const SizedBox()));
    await t.pumpWidget(app(_batching));
    await settle(t);
    expect(find.byType(UiKitView), findsOneWidget);
    expect(_shapes(sent), hasLength(25));
  }, variant: ios);

  testWidgets('glass in a scroll view joins only a batch inside it', (t) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(
      host(GlassBatch(child: SingleChildScrollView(child: _chips(6)))),
    );
    await settle(t);
    expect(find.byType(UiKitView), findsNWidgets(6));

    await t.pumpWidget(host(const SizedBox()));
    await t.pumpWidget(
      host(SingleChildScrollView(child: GlassBatch(child: _chips(6)))),
    );
    await settle(t);
    expect(find.byType(UiKitView), findsOneWidget);
  }, variant: ios);

  testWidgets('glass over a painted ancestor keeps its own view', (t) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(
      host(
        Align(
          child: GlassBatch(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chips(3),
                ColoredBox(color: const Color(0xFFFFFFFF), child: _chip(9)),
                DecoratedBox(
                  decoration: const BoxDecoration(color: Color(0xFF000000)),
                  child: _chip(10),
                ),
                // Paints nothing: still batched.
                DecoratedBox(
                  decoration: const BoxDecoration(),
                  child: _chip(11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(t);
    // The batch (4 chips) plus the two over a painted ancestor.
    expect(find.byType(UiKitView), findsNWidgets(3));
  }, variant: ios);

  testWidgets('glass over an earlier sibling is given back', (t) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(
      host(
        Align(
          child: GlassBatch(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chip(0),
                SizedBox(
                  width: 200,
                  height: 60,
                  child: Stack(
                    children: [
                      const Positioned.fill(child: SizedBox.expand()),
                      Center(child: _chip(1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(t);
    // The batch draws chip 0; chip 1 sits over its earlier sibling.
    expect(find.byType(UiKitView), findsNWidgets(2));
  }, variant: ios);

  testWidgets('rotated glass is given back', (t) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(
      host(
        Align(
          child: GlassBatch(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chip(0),
                const SizedBox(height: 40),
                Transform.rotate(angle: math.pi / 8, child: _chip(1)),
                const SizedBox(height: 40),
                // Scaled is fine: the rect stays axis-aligned.
                Transform.scale(scale: 1.5, child: _chip(2)),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(t);
    expect(find.byType(UiKitView), findsNWidgets(2));
  }, variant: ios);

  testWidgets('opacity between glass and the batch reaches the shape', (
    t,
  ) async {
    iosEnv();
    final sent = mockNative(t);
    await t.pumpWidget(
      host(
        Align(
          child: GlassBatch(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chip(0),
                Opacity(opacity: 0.5, child: _chip(1)),
                Opacity(opacity: 0, child: _chip(2)),
                Offstage(child: _chip(3)),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(t);
    expect(find.byType(UiKitView), findsOneWidget);
    final shapes = _shapes(sent);
    expect(shapes, hasLength(2));
    expect(shapes[0].containsKey('opacity'), isFalse);
    expect(shapes[1]['opacity'], 0.5);
  }, variant: ios);

  testWidgets('a fade between glass and the batch is followed', (t) async {
    iosEnv();
    final sent = mockNative(t);
    final fade = AnimationController(vsync: const TestVSync(), value: 1);
    addTearDown(fade.dispose);
    await t.pumpWidget(
      host(
        Align(
          child: GlassBatch(
            child: FadeTransition(opacity: fade, child: _chip(0)),
          ),
        ),
      ),
    );
    await settle(t);
    expect(_shapes(sent).single.containsKey('opacity'), isFalse);
    fade.value = 0.25;
    await t.pump();
    expect(_shapes(sent).single['opacity'], 0.25);
    expect(find.byType(UiKitView), findsOneWidget);
  }, variant: ios);

  testWidgets('clips: cut glass is given back, hidden glass left out', (
    t,
  ) async {
    iosEnv();
    final sent = mockNative(t);
    await t.pumpWidget(
      host(
        Align(
          child: GlassBatch(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _chip(0),
                // Half the chip's height: cut.
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 0.5,
                    child: _chip(1),
                  ),
                ),
                // Clipped away entirely.
                SizedBox(
                  height: 10,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxHeight: 200,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 100),
                        child: _chip(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(t);
    expect(find.byType(UiKitView), findsNWidgets(2));
    Finder ownView(String label) => find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(NativeGlassLayer),
      ),
      matching: find.byType(UiKitView),
    );
    expect(ownView('Tag 0'), findsNothing);
    expect(ownView('Tag 1'), findsOneWidget);
    expect(ownView('Tag 2'), findsNothing);
    // The batch draws chip 0 alone.
    expect(sent.where((p) => (p['shapes']! as List).length > 1), isEmpty);
  }, variant: ios);

  testWidgets('glass shown through an OverlayPortal is given back', (t) async {
    iosEnv();
    mockNative(t);
    final portal = OverlayPortalController()..show();
    await t.pumpWidget(
      host(
        Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => Align(
                child: GlassBatch(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _chip(0),
                      OverlayPortal(
                        controller: portal,
                        overlayChildBuilder: (_) =>
                            Positioned(left: 0, top: 0, child: _chip(1)),
                        child: const SizedBox(width: 10, height: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await settle(t);
    expect(find.byType(UiKitView), findsNWidgets(2));
  }, variant: ios);

  testWidgets('a batch does nothing off the native path', (t) async {
    iosEnv();
    mockNative(t);
    await t.pumpWidget(
      host(
        LiquidGlassTheme(
          data: const LiquidGlassThemeData(
            defaultMode: GlassRenderMode.shader,
            batchImplicitGroups: true,
          ),
          child: Align(child: GlassBatch(child: _chips(4))),
        ),
      ),
    );
    await settle(t);
    expect(find.byType(UiKitView), findsNothing);
  }, variant: ios);

  test('batchImplicitGroups is off by default and copied', () {
    const data = LiquidGlassThemeData();
    expect(data.batchImplicitGroups, isFalse);
    expect(data.copyWith(batchImplicitGroups: true).batchImplicitGroups, true);
    expect(data.copyWith(batchImplicitGroups: true) == data, isFalse);
    expect(data.copyWith(batchImplicitGroups: true), _batching);
  });
}
