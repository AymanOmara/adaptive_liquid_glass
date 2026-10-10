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

  testWidgets('in GlassScaffold: the last row scrolls clear of the tab bar', (
    t,
  ) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: GlassTabBar(
          items: const [
            GlassTabBarItem(icon: Icons.home, label: 'Home'),
            GlassTabBarItem(icon: Icons.settings, label: 'More'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
        ),
        body: GlassLargeTitleScrollView(
          navigationBar: const SliverGlassNavigationBar(
            largeTitle: Text('Inbox'),
          ),
          body: _rows(),
        ),
      ),
    );
    await t.fling(find.text('Row 3'), const Offset(0, -6000), 8000);
    await t.pumpAndSettle();
    final last = t.getRect(find.text('Row 59'));
    expect(
      last.bottom,
      lessThanOrEqualTo(t.getRect(find.byType(GlassTabBar)).top),
    );
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Material in GlassScaffold, edge to edge: last row clear', (
    t,
  ) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: GlassTabBar(
          items: const [
            GlassTabBarItem(icon: Icons.home, label: 'Home'),
            GlassTabBarItem(icon: Icons.settings, label: 'More'),
          ],
          selectedIndex: 0,
          onSelected: (_) {},
          materialStyle: GlassMaterialTabBarStyle.edgeToEdge,
        ),
        body: GlassLargeTitleScrollView(
          navigationBar: const SliverGlassNavigationBar(
            largeTitle: Text('Inbox'),
          ),
          body: _rows(),
        ),
      ),
    );
    await t.fling(find.text('Row 3'), const Offset(0, -6000), 8000);
    await t.pumpAndSettle();
    expect(
      t.getRect(find.text('Row 59')).bottom,
      lessThanOrEqualTo(t.getRect(find.byType(NavigationBar)).top),
    );
  }, variant: android);

  testWidgets('scrolling back to the top brings the large title back', (
    t,
  ) async {
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
    await t.fling(find.text('Row 3'), const Offset(0, -3000), 6000);
    await t.pumpAndSettle();
    await t.fling(find.byType(ListView), const Offset(0, 6000), 8000);
    await t.pumpAndSettle();
    expect(t.getRect(_large).top, moreOrLessEquals(rest));
    expect(t.getRect(find.text('Row 0')).top, greaterThan(rest));
  }, variant: ios);

  testWidgets('RTL: the large title at the right', (t) async {
    shaderEnv();
    await _pump(
      t,
      Directionality(
        textDirection: TextDirection.rtl,
        child: GlassLargeTitleScrollView(
          navigationBar: const SliverGlassNavigationBar(
            largeTitle: Text('Inbox'),
          ),
          body: _rows(),
        ),
      ),
    );
    expect(
      402 - t.getRect(_large).right,
      moreOrLessEquals(NavBarMetrics.largeTitleInset, epsilon: 0.5),
    );
  }, variant: ios);

  testWidgets('large text: no overflow', (t) async {
    shaderEnv();
    await _pump(
      t,
      MediaQuery.withClampedTextScaling(
        minScaleFactor: 2,
        maxScaleFactor: 2,
        child: GlassLargeTitleScrollView(
          navigationBar: const SliverGlassNavigationBar(
            largeTitle: Text('Inbox'),
          ),
          body: _rows(),
        ),
      ),
    );
    await t.drag(find.text('Row 3'), const Offset(0, -300));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('a pushed page shows the back button', (t) async {
    shaderEnv();
    await _pump(t, const SizedBox());
    final nav = t.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: GlassLargeTitleScrollView(
            navigationBar: const SliverGlassNavigationBar(
              largeTitle: Text('Inbox'),
            ),
            body: _rows(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsOneWidget);
    await t.tap(find.byType(GlassBackButton));
    await t.pumpAndSettle();
    expect(find.text('Inbox'), findsNothing);
  }, variant: ios);

  testWidgets('Material: pull to refresh on the body still works', (t) async {
    shaderEnv();
    var refreshed = 0;
    await _pump(
      t,
      GlassLargeTitleScrollView(
        navigationBar: const SliverGlassNavigationBar(
          largeTitle: Text('Inbox'),
        ),
        body: RefreshIndicator(
          onRefresh: () async => refreshed++,
          child: _rows(),
        ),
      ),
    );
    await t.fling(find.text('Row 1'), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect(refreshed, 1);
  }, variant: android);

  testWidgets('pulling down at the top: no exception, settles back', (t) async {
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
    final g = await t.startGesture(t.getCenter(find.text('Row 2')));
    await g.moveBy(const Offset(0, 150));
    await t.pump();
    // ignore: avoid_print
    print('pulled title top ${t.getRect(_large).top} (rest $rest)');
    await g.up();
    await t.pumpAndSettle();
    expect(t.getRect(_large).top, moreOrLessEquals(rest));
    expect(t.takeException(), isNull);
  }, variant: ios);
}
