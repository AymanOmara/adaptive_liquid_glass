import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

void env() => GlassPlatform.instance.debugEnvironment = const GlassEnvironment(
  platform: TargetPlatform.iOS,
  iosMajorVersion: 18,
  reduceTransparency: false,
  shaderSupported: true,
);

List<Rect> shapes(WidgetTester t) => t
    .renderObject<RenderGlassBackdrop>(find.byType(GlassBackdrop))
    .debugLastFrame!
    .uniforms
    .shapes
    .map((s) => s.rect)
    .toList();

/// Test hosts need a MediaQuery (the group reads the device pixel ratio).
Widget scene({
  required bool showB,
  bool bOnRight = false,
  bool keepKey = false,
}) => MediaQuery(
  data: MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.implicitView!,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: GlassGroup(
        spacing: 10,
        child: SizedBox(
          width: 300,
          height: 60,
          child: Stack(
            children: [
              const PositionedDirectional(
                start: 0,
                top: 0,
                child: LiquidGlass(
                  glassId: 'a',
                  child: SizedBox(width: 60, height: 60),
                ),
              ),
              if (showB)
                PositionedDirectional(
                  start: bOnRight ? 240 : 80,
                  top: 0,
                  child: LiquidGlass(
                    key: ValueKey(keepKey ? false : bOnRight),
                    glassId: 'b',
                    child: const SizedBox(width: 60, height: 60),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('first frame does not animate', (t) async {
    env();
    await t.pumpWidget(scene(showB: true));
    expect(shapes(t), hasLength(2));
    await t.pump(const Duration(milliseconds: 16));
    final s = shapes(t);
    expect(s[1].width, s[0].width);
  }, variant: ios);

  testWidgets('appearing glass grows from its neighbour', (t) async {
    env();
    await t.pumpWidget(scene(showB: false));
    await t.pump();
    await t.pumpWidget(scene(showB: true));
    expect(shapes(t), hasLength(1)); // hidden on its first frame
    await t.pump(); // spring starts: drawn at 'a'
    final start = shapes(t);
    expect(start, hasLength(2));
    await t.pump(const Duration(milliseconds: 50));
    final mid = shapes(t);
    expect(mid, hasLength(2));
    final dpr = t.view.devicePixelRatio;
    expect(mid[1].left, greaterThan(start[1].left)); // moving toward 80
    expect(mid[1].left, lessThan(80 * dpr)); // still travelling from 'a'
    await t.pumpAndSettle();
    expect(shapes(t)[1].left, closeTo(80 * dpr, 0.5));
  }, variant: ios);

  testWidgets('removed glass shrinks into its neighbour, then disappears', (
    t,
  ) async {
    env();
    await t.pumpWidget(scene(showB: true));
    await t.pump();
    await t.pumpWidget(scene(showB: false));
    expect(shapes(t), hasLength(2)); // ghost
    final dpr = t.view.devicePixelRatio;
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    final s = shapes(t);
    expect(s, hasLength(2));
    // Shrinking toward 'a''s centre: b's centre started 80 away.
    expect(s[1].width, lessThan(60 * dpr));
    expect((s[1].center - s[0].center).distance, lessThan(80 * dpr));
    await t.pumpAndSettle();
    expect(shapes(t), hasLength(1));
  }, variant: ios);

  testWidgets('same id in a new place morphs from the old rect', (t) async {
    env();
    await t.pumpWidget(scene(showB: true));
    await t.pump();
    await t.pumpWidget(scene(showB: true, bOnRight: true));
    // The spring starts after layout; its first tick is at zero elapsed.
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    final dpr = t.view.devicePixelRatio;
    expect(shapes(t), hasLength(2)); // no ghost of the old view
    final b = shapes(t)[1];
    expect(b.left, greaterThan(80 * dpr));
    expect(b.left, lessThan(240 * dpr));
    await t.pumpAndSettle();
    expect(shapes(t), hasLength(2));
    expect(shapes(t)[1].left, closeTo(240 * dpr, 0.5));
  }, variant: ios);

  testWidgets('a re-added id takes over its ghost instead of hiding', (
    t,
  ) async {
    env();
    await t.pumpWidget(scene(showB: true));
    await t.pump();
    await t.pumpWidget(scene(showB: false));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50)); // ghost shrinking
    await t.pumpWidget(scene(showB: true));
    expect(shapes(t), hasLength(2)); // drawn at the ghost's rect, not hidden
    await t.pumpAndSettle();
    final dpr = t.view.devicePixelRatio;
    expect(shapes(t), hasLength(2));
    expect(shapes(t)[1].left, closeTo(80 * dpr, 0.5));
    expect(shapes(t)[1].width, closeTo(60 * dpr, 0.5));
  }, variant: ios);

  testWidgets('a layout change of a live member does not morph', (t) async {
    env();
    await t.pumpWidget(scene(showB: true));
    await t.pump();
    await t.pumpWidget(scene(showB: true, bOnRight: true, keepKey: true));
    final dpr = t.view.devicePixelRatio;
    expect(shapes(t)[1].left, closeTo(240 * dpr, 0.5));
    await t.pump(const Duration(milliseconds: 16));
    expect(shapes(t)[1].left, closeTo(240 * dpr, 0.5));
    expect(shapes(t)[1].width, closeTo(60 * dpr, 0.5));
  }, variant: ios);

  testWidgets('disposing the group mid-morph leaks no tickers', (t) async {
    env();
    await t.pumpWidget(scene(showB: false));
    await t.pump();
    await t.pumpWidget(scene(showB: true)); // appearing
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    await t.pumpWidget(scene(showB: false)); // ghost
    await t.pump(const Duration(milliseconds: 16));
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(t.binding.hasScheduledFrame, isFalse);
  }, variant: ios);

  testWidgets('content composites only while fading', (t) async {
    env();
    await t.pumpWidget(scene(showB: false));
    await t.pump();
    expect(t.layers.whereType<OpacityLayer>(), isEmpty); // settled
    await t.pumpWidget(scene(showB: true));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(t.layers.whereType<OpacityLayer>(), hasLength(1)); // mid-fade
    await t.pumpAndSettle();
    expect(t.layers.whereType<OpacityLayer>(), isEmpty);
  }, variant: ios);
}
