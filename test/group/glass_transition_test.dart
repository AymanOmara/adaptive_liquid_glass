import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
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

Widget scene({
  required bool showB,
  required GlassTransition transition,
  Object? id = 'b',
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
                  start: 200,
                  top: 0,
                  child: LiquidGlass(
                    glassId: id,
                    transition: transition,
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

  testWidgets('materialize swells in place, not from a neighbour', (t) async {
    env();
    const mat = GlassTransition.materialize;
    await t.pumpWidget(scene(showB: false, transition: mat));
    await t.pump();
    await t.pumpWidget(scene(showB: true, transition: mat));
    await t.pump();
    await t.pump(const Duration(milliseconds: 30));
    final dpr = t.view.devicePixelRatio;
    final b = shapes(t)[1];
    expect(b.center.dx, closeTo(230 * dpr, 1)); // never left its own frame
    expect(b.width, lessThan(60 * dpr));
    await t.pumpAndSettle();
    expect(shapes(t)[1].width, closeTo(60 * dpr, 0.5));
  }, variant: ios);

  testWidgets('materialize works without a glassId', (t) async {
    env();
    const mat = GlassTransition.materialize;
    await t.pumpWidget(scene(showB: false, transition: mat, id: null));
    await t.pump();
    await t.pumpWidget(scene(showB: true, transition: mat, id: null));
    await t.pump();
    await t.pump(const Duration(milliseconds: 30));
    final dpr = t.view.devicePixelRatio;
    expect(shapes(t)[1].width, lessThan(60 * dpr));
    await t.pumpAndSettle();
    expect(shapes(t)[1].width, closeTo(60 * dpr, 0.5));
  }, variant: ios);

  testWidgets('materialize removal shrinks in place then goes', (t) async {
    env();
    const mat = GlassTransition.materialize;
    await t.pumpWidget(scene(showB: true, transition: mat));
    await t.pump();
    await t.pumpWidget(scene(showB: false, transition: mat));
    expect(shapes(t), hasLength(2)); // ghost
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    final dpr = t.view.devicePixelRatio;
    final b = shapes(t)[1];
    expect(b.center.dx, closeTo(230 * dpr, 1));
    expect(b.width, lessThan(60 * dpr));
    await t.pumpAndSettle();
    expect(shapes(t), hasLength(1));
  }, variant: ios);

  testWidgets('identity appears at once, even with a glassId', (t) async {
    env();
    const id = GlassTransition.identity;
    await t.pumpWidget(scene(showB: false, transition: id));
    await t.pump();
    await t.pumpWidget(scene(showB: true, transition: id));
    await t.pump();
    final dpr = t.view.devicePixelRatio;
    expect(shapes(t), hasLength(2));
    expect(shapes(t)[1].width, closeTo(60 * dpr, 0.5));
    await t.pumpWidget(scene(showB: false, transition: id));
    await t.pump();
    expect(shapes(t), hasLength(1)); // no ghost
  }, variant: ios);

  testWidgets('matchedGeometry grows from the neighbour (default)', (t) async {
    env();
    const m = GlassTransition.matchedGeometry;
    await t.pumpWidget(scene(showB: false, transition: m));
    await t.pump();
    await t.pumpWidget(scene(showB: true, transition: m));
    await t.pump();
    await t.pump(const Duration(milliseconds: 30));
    final dpr = t.view.devicePixelRatio;
    expect(shapes(t)[1].center.dx, lessThan(230 * dpr - 20));
  }, variant: ios);

  test('LiquidGlass defaults to matchedGeometry', () {
    expect(
      const LiquidGlass(child: SizedBox()).transition,
      GlassTransition.matchedGeometry,
    );
  });
}
