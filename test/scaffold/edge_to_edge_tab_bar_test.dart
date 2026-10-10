import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _items = [
  GlassTabBarItem(icon: CupertinoIcons.clock_fill, label: 'History'),
  GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
];

GlassTabBar _bar({
  int selected = 0,
  ValueChanged<int>? onSelected,
  VoidCallback? onSearch,
  GlassMaterialTabBarStyle style = GlassMaterialTabBarStyle.edgeToEdge,
}) => GlassTabBar(
  items: _items,
  selectedIndex: selected,
  onSelected: onSelected ?? (_) {},
  onSearch: onSearch,
  materialStyle: style,
);

Future<void> _pump(
  WidgetTester t,
  Widget scaffold, {
  double bottom = 34,
  TextDirection dir = TextDirection.ltr,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  t.view.padding = FakeViewPadding(top: 62, bottom: bottom);
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (c, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: Directionality(textDirection: dir, child: child!),
      ),
      home: scaffold,
    ),
  );
}

EdgeInsets _bodyPadding(WidgetTester t) =>
    MediaQuery.paddingOf(t.element(find.byKey(const Key('body'))));

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('with an accessory: accessory above the bar, body clears both', (
    t,
  ) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _bar(),
        bottomAccessory: const GlassBottomAccessory(
          key: Key('acc'),
          child: Text('Now playing'),
        ),
        body: const SizedBox(key: Key('body')),
      ),
    );
    final bar = t.getRect(find.byType(NavigationBar));
    final acc = t.getRect(find.byKey(const Key('acc')));
    expect(bar.bottom, 874);
    expect(bar.width, 402);
    expect(acc.bottom, moreOrLessEquals(bar.top - 8));
    expect(acc.top, greaterThan(0));
    expect(_bodyPadding(t).bottom, moreOrLessEquals(874 - acc.top));
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets('without a home indicator: on the edge, no extra padding', (
    t,
  ) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _bar(),
        body: const SizedBox(key: Key('body')),
      ),
      bottom: 0,
    );
    final bar = t.getRect(find.byType(NavigationBar));
    expect(bar.bottom, 874);
    expect(bar.height, 62);
    expect(_bodyPadding(t).bottom, 62);
  }, variant: android);

  testWidgets('tabs select by index; search does not select', (t) async {
    shaderEnv();
    final picked = <int>[];
    var searched = 0;
    await _pump(
      t,
      GlassScaffold(
        tabBar: _bar(onSelected: picked.add, onSearch: () => searched++),
        body: const SizedBox(key: Key('body')),
      ),
    );
    await t.tap(find.text('Settings'));
    await t.tap(find.text('History'));
    await t.tap(find.text('Search'));
    await t.pumpAndSettle();
    expect(picked, [1, 0]);
    expect(searched, 1);
  }, variant: android);

  testWidgets('no search tab without onSearch', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _bar(),
        body: const SizedBox(key: Key('body')),
      ),
    );
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('Search'), findsNothing);
  }, variant: android);

  testWidgets('RTL: full width, first tab at the right', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _bar(),
        body: const SizedBox(key: Key('body')),
      ),
      dir: TextDirection.rtl,
    );
    expect(t.getRect(find.byType(NavigationBar)).width, 402);
    expect(
      t.getCenter(find.text('History')).dx,
      greaterThan(t.getCenter(find.text('Settings')).dx),
    );
  }, variant: android);

  testWidgets('large text and dark mode: no overflow', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _bar(onSearch: () {}),
        body: const SizedBox(key: Key('body')),
      ),
      textScale: 2,
      brightness: Brightness.dark,
    );
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets('switching floating <-> edge to edge at runtime', (t) async {
    shaderEnv();
    var style = GlassMaterialTabBarStyle.floating;
    late StateSetter set;
    await _pump(
      t,
      StatefulBuilder(
        builder: (context, s) {
          set = s;
          return GlassScaffold(
            tabBar: _bar(style: style),
            body: const SizedBox(key: Key('body')),
          );
        },
      ),
    );
    expect(t.getRect(find.byType(NavigationBar)).bottom, 874 - 21);
    expect(_bodyPadding(t).bottom, 21 + 62);
    set(() => style = GlassMaterialTabBarStyle.edgeToEdge);
    await t.pumpAndSettle();
    expect(t.getRect(find.byType(NavigationBar)).bottom, 874);
    expect(_bodyPadding(t).bottom, 62 + 34);
    set(() => style = GlassMaterialTabBarStyle.floating);
    await t.pumpAndSettle();
    expect(t.getRect(find.byType(NavigationBar)).bottom, 874 - 21);
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets('a bar outside GlassScaffold fills its width', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(alignment: Alignment.bottomCenter, child: _bar()),
        ),
      ),
    );
    expect(t.getRect(find.byType(NavigationBar)).width, 800);
    expect(t.takeException(), isNull);
  }, variant: android);

  testWidgets('a forced shader bar ignores edge to edge on Android', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: GlassTabBar(
          items: _items,
          selectedIndex: 0,
          onSelected: (_) {},
          mode: GlassRenderMode.shader,
          materialStyle: GlassMaterialTabBarStyle.edgeToEdge,
        ),
        body: const SizedBox(key: Key('body')),
      ),
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      t.getRect(find.byType(GlassTabBar)).bottom,
      moreOrLessEquals(874 - 21),
    );
  }, variant: android);

  testWidgets('Material bar never takes the status bar padding', (t) async {
    shaderEnv();
    for (final style in GlassMaterialTabBarStyle.values) {
      await _pump(
        t,
        GlassScaffold(
          tabBar: _bar(style: style),
          body: const SizedBox(key: Key('body')),
        ),
      );
      final bar = t.getRect(find.byType(NavigationBar));
      expect(
        bar.height,
        style == GlassMaterialTabBarStyle.floating ? 62 : 62 + 34,
        reason: '$style',
      );
    }
    // Outside GlassScaffold, in a Scaffold body that keeps the top inset.
    await _pump(
      t,
      Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: _bar()),
      ),
    );
    expect(t.getRect(find.byType(NavigationBar)).height, 62 + 34);
  }, variant: android);
}
