import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/navigation/nav_bar_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _rows() => ListView.builder(
  itemCount: 60,
  itemBuilder: (_, i) => SizedBox(height: 44, child: Text('Row $i')),
);

Finder get _large => find.descendant(
  of: find.byWidgetPredicate(
    (w) =>
        w is DefaultTextStyle &&
        w.style.fontSize == NavBarMetrics.largeTitleFontSize,
  ),
  matching: find.text('Inbox'),
);

Future<void> _pump(WidgetTester t, Widget body) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: Scaffold(body: body)));
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a list in SliverFillRemaining keeps the title (the trap)', (
    t,
  ) async {
    shaderEnv();
    await _pump(
      t,
      CustomScrollView(
        slivers: [
          const SliverGlassNavigationBar(largeTitle: Text('Inbox')),
          SliverFillRemaining(child: _rows()),
        ],
      ),
    );
    final rest = t.getRect(_large).top;
    await t.drag(find.text('Row 3'), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(t.getRect(_large).top, rest);
  }, variant: ios);

  testWidgets('scrolling the body collapses the large title', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassLargeTitleScrollView(
        navigationBar: const SliverGlassNavigationBar(
          largeTitle: Text('Inbox'),
        ),
        body: _rows(),
      ),
    );
    final rest = t.getRect(_large).top;
    // The first row starts right under the large title, not a status bar
    // lower.
    expect(
      t.getRect(find.text('Row 0')).top,
      moreOrLessEquals(
        62 + NavBarMetrics.barHeight + NavBarMetrics.largeTitleHeight,
      ),
    );
    await t.drag(find.text('Row 3'), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(t.getRect(_large).top, lessThan(rest));
    final inline = t.widget<AnimatedOpacity>(
      find.ancestor(
        of: find.byWidgetPredicate(
          (w) =>
              w is DefaultTextStyle &&
              w.style.fontSize == NavBarMetrics.titleFontSize,
        ),
        matching: find.byType(AnimatedOpacity),
      ),
    );
    expect(inline.opacity, 1);
  }, variant: ios);

  testWidgets('Material: SliverAppBar.large collapses too', (t) async {
    shaderEnv();
    final outer = ScrollController();
    await _pump(
      t,
      GlassLargeTitleScrollView(
        controller: outer,
        navigationBar: const SliverGlassNavigationBar(
          largeTitle: Text('Inbox'),
        ),
        body: _rows(),
      ),
    );
    expect(find.byType(SliverAppBar), findsOneWidget);
    await t.drag(find.text('Row 3'), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(outer.offset, outer.position.maxScrollExtent);
    expect(outer.offset, greaterThan(0));
  }, variant: android);
}
