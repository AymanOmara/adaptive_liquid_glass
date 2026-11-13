import 'package:adaptive_liquid_glass/src/page_control/glass_page_control.dart';
import 'package:adaptive_liquid_glass/src/page_control/glass_page_view.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _pages(int n) => SizedBox(
  width: 400,
  height: 600,
  child: GlassPageView(children: [for (var i = 0; i < n; i++) Text('Page $i')]),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('swiping moves the page and reports it; dots follow', (t) async {
    shaderEnv();
    final controller = PageController();
    addTearDown(controller.dispose);
    final settled = <int>[];
    await t.pumpWidget(
      plainHost(
        SizedBox(
          width: 400,
          height: 600,
          child: GlassPageView(
            controller: controller,
            onPageChanged: settled.add,
            children: const [Text('A'), Text('B'), Text('C')],
          ),
        ),
      ),
    );
    final dots = t.widget<GlassPageControl>(find.byType(GlassPageControl));
    expect(dots.count, 3);
    expect(dots.controller, same(controller));

    await t.fling(find.text('A'), const Offset(-300, 0), 1000);
    await t.pumpAndSettle();
    expect(controller.page, 1);
    expect(settled, [1]);
    expect(find.text('B'), findsOneWidget);
  }, variant: ios);

  testWidgets('dots float above the bottom edge, centred', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_pages(3)));
    final view = t.getRect(find.byType(GlassPageView));
    final dots = t.getRect(find.byType(GlassPageControl));
    expect(dots.center.dx, closeTo(view.center.dx, 0.5));
    expect(dots.bottom, lessThan(view.bottom));
  }, variant: ios);

  testWidgets('automatic hides the dots for one page; always shows them', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_pages(1)));
    expect(find.byType(GlassPageControl), findsNothing);
    await t.pumpWidget(
      plainHost(
        const SizedBox(
          width: 400,
          height: 600,
          child: GlassPageView(
            indexDisplayMode: GlassPageIndexDisplayMode.always,
            children: [Text('Only')],
          ),
        ),
      ),
    );
    expect(find.byType(GlassPageControl), findsOneWidget);
  }, variant: ios);

  testWidgets('never hides the dots', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const SizedBox(
          width: 400,
          height: 600,
          child: GlassPageView(
            indexDisplayMode: GlassPageIndexDisplayMode.never,
            children: [Text('A'), Text('B')],
          ),
        ),
      ),
    );
    expect(find.byType(GlassPageControl), findsNothing);
  }, variant: ios);

  testWidgets('builder pages build on demand', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        SizedBox(
          width: 400,
          height: 600,
          child: GlassPageView.builder(
            itemCount: 6,
            itemBuilder: (_, i) => Text('Item $i'),
          ),
        ),
      ),
    );
    expect(find.text('Item 0'), findsOneWidget);
    expect(find.text('Item 5'), findsNothing);
    expect(t.widget<GlassPageControl>(find.byType(GlassPageControl)).count, 6);
  }, variant: ios);

  testWidgets('Material path keeps the dots', (t) async {
    await t.pumpWidget(plainHost(_pages(3)));
    expect(find.byType(GlassPageControl), findsOneWidget);
  }, variant: android);
}
