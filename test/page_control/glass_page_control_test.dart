import 'package:adaptive_liquid_glass/src/liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/page_control/glass_page_control.dart';
import 'package:adaptive_liquid_glass/src/page_control/page_control_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

List<double> _opacities(WidgetTester t) => find
    .descendant(
      of: find.byType(GlassPageControl),
      matching: find.byType(AnimatedOpacity),
    )
    .evaluate()
    .map((e) => (e.widget as AnimatedOpacity).opacity)
    .toList();

Finder _dots(WidgetTester t) => find.descendant(
  of: find.byType(GlassPageControl),
  matching: find.byType(AnimatedContainer),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('glass capsule of dots; the current one is opaque', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        GlassPageControl(count: 3, currentPage: 1, onPageChanged: (_) {}),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(GlassPageControl),
        matching: find.byType(LiquidGlass),
      ),
      findsOneWidget,
    );
    expect(_opacities(t), [
      PageControlMetrics.inactiveOpacity,
      1,
      PageControlMetrics.inactiveOpacity,
    ]);
    expect(
      t.getSize(find.byType(GlassPageControl)).height,
      PageControlMetrics.height,
    );
  }, variant: ios);

  testWidgets('tapping the halves steps the page', (t) async {
    shaderEnv();
    var picked = -1;
    await t.pumpWidget(
      plainHost(
        GlassPageControl(
          count: 3,
          currentPage: 1,
          onPageChanged: (p) => picked = p,
        ),
      ),
    );
    final topLeft = t.getTopLeft(find.byType(GlassPageControl));
    final size = t.getSize(find.byType(GlassPageControl));
    await t.tapAt(topLeft + Offset(size.width / 4, size.height / 2));
    await t.pump();
    expect(picked, 0);
    await t.tapAt(topLeft + Offset(size.width * 3 / 4, size.height / 2));
    await t.pump();
    expect(picked, 2);
  }, variant: ios);

  testWidgets('taps clamp at the bounds', (t) async {
    shaderEnv();
    final picked = <int>[];
    await t.pumpWidget(
      plainHost(
        GlassPageControl(count: 3, currentPage: 0, onPageChanged: picked.add),
      ),
    );
    final topLeft = t.getTopLeft(find.byType(GlassPageControl));
    final size = t.getSize(find.byType(GlassPageControl));
    await t.tapAt(topLeft + Offset(size.width / 4, size.height / 2));
    await t.pump();
    expect(picked, isEmpty);
    await t.tapAt(topLeft + Offset(size.width * 3 / 4, size.height / 2));
    await t.pump();
    expect(picked, [1]);
  }, variant: ios);

  testWidgets('right to left: the right half goes back', (t) async {
    shaderEnv();
    var picked = -1;
    await t.pumpWidget(
      plainHost(
        GlassPageControl(
          count: 3,
          currentPage: 1,
          onPageChanged: (p) => picked = p,
        ),
        direction: TextDirection.rtl,
      ),
    );
    final topLeft = t.getTopLeft(find.byType(GlassPageControl));
    final size = t.getSize(find.byType(GlassPageControl));
    await t.tapAt(topLeft + Offset(size.width * 3 / 4, size.height / 2));
    await t.pump();
    expect(picked, 0);
    await t.tapAt(topLeft + Offset(size.width / 4, size.height / 2));
    await t.pump();
    expect(picked, 2);
  }, variant: ios);

  testWidgets('dragging scrubs the dot under the finger', (t) async {
    shaderEnv();
    final picked = <int>[];
    await t.pumpWidget(
      plainHost(
        GlassPageControl(count: 3, currentPage: 0, onPageChanged: picked.add),
      ),
    );
    final topLeft = t.getTopLeft(find.byType(GlassPageControl));
    final firstDot =
        topLeft +
        const Offset(
          PageControlMetrics.horizontalPadding + PageControlMetrics.dotSize / 2,
          PageControlMetrics.height / 2,
        );
    final gesture = await t.startGesture(firstDot);
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(10, 0));
    }
    await gesture.up();
    await t.pump();
    expect(picked, isNotEmpty);
    expect(picked.last, 2);
  }, variant: ios);

  testWidgets('follows and drives a PageController', (t) async {
    shaderEnv();
    final controller = PageController();
    final picked = <int>[];
    await t.pumpWidget(
      plainHost(
        SizedBox(
          width: 400,
          height: 600,
          child: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: controller,
                  children: const [
                    SizedBox.expand(),
                    SizedBox.expand(),
                    SizedBox.expand(),
                  ],
                ),
              ),
              GlassPageControl(
                count: 3,
                controller: controller,
                onPageChanged: picked.add,
              ),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    // Tapping the end half moves the PageView to page 1.
    final topLeft = t.getTopLeft(find.byType(GlassPageControl));
    final size = t.getSize(find.byType(GlassPageControl));
    await t.tapAt(topLeft + Offset(size.width * 3 / 4, size.height / 2));
    await t.pumpAndSettle();
    expect(controller.page, 1);
    expect(picked, [1]);
    expect(_opacities(t)[1], 1);
    // Swiping the PageView moves the control's current dot.
    await t.drag(find.byType(PageView), const Offset(-400, 0));
    await t.pumpAndSettle();
    expect(controller.page, 2);
    expect(_opacities(t), [
      PageControlMetrics.inactiveOpacity,
      PageControlMetrics.inactiveOpacity,
      1,
    ]);
    // Two quick taps back count from the picked page, not the lagging one.
    picked.clear();
    final start = topLeft + Offset(size.width / 4, size.height / 2);
    await t.tapAt(start);
    await t.pump(const Duration(milliseconds: 50));
    await t.tapAt(start);
    await t.pumpAndSettle();
    expect(picked, [1, 0]);
    expect(controller.page, 0);
  }, variant: ios);

  testWidgets('semantics: value and increase move the page', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    var picked = -1;
    await t.pumpWidget(
      plainHost(
        GlassPageControl(
          count: 3,
          currentPage: 0,
          onPageChanged: (p) => picked = p,
        ),
      ),
    );
    final node = find.semantics.byLabel('Page').evaluate().single;
    expect(node.value, '1 of 3');
    expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    node.owner!.performAction(node.id, SemanticsAction.increase);
    await t.pump();
    expect(picked, 1);
    handle.dispose();
  }, variant: ios);

  testWidgets('inert without a callback or controller', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(const GlassPageControl(count: 3, currentPage: 1)),
    );
    await t.tapAt(t.getCenter(find.byType(GlassPageControl)));
    await t.pump();
    final data = find.semantics
        .byLabel('Page')
        .evaluate()
        .single
        .getSemanticsData();
    expect(data.hasAction(SemanticsAction.increase), isFalse);
    expect(data.hasAction(SemanticsAction.decrease), isFalse);
    expect(_opacities(t)[1], 1);
    handle.dispose();
  }, variant: ios);

  testWidgets('Material: dots; tapping a dot picks it', (t) async {
    shaderEnv();
    var picked = -1;
    await t.pumpWidget(
      appHost(
        GlassPageControl(
          count: 3,
          currentPage: 0,
          onPageChanged: (p) => picked = p,
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(GlassPageControl),
        matching: find.byType(LiquidGlass),
      ),
      findsNothing,
    );
    final dots = _dots(t);
    expect(dots, findsNWidgets(3));
    expect(t.getSize(dots.at(0)).width, PageControlMetrics.materialActiveWidth);
    expect(t.getSize(dots.at(1)).width, PageControlMetrics.materialDotSize);
    await t.tap(dots.at(2));
    await t.pump();
    expect(picked, 2);
  }, variant: android);

  testWidgets('Material: inert without a callback or controller', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(const GlassPageControl(count: 3, currentPage: 0)),
    );
    await t.tapAt(t.getCenter(_dots(t).at(2)));
    await t.pump();
    expect(
      t.getSize(_dots(t).at(0)).width,
      PageControlMetrics.materialActiveWidth,
    );
  }, variant: android);
}
