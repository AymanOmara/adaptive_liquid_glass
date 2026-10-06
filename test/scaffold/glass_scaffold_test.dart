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

GlassTabBar _tabBar() =>
    GlassTabBar(items: _items, selectedIndex: 0, onSelected: (_) {});

/// Pumps [scaffold] in an app on a phone-shaped view with a home indicator.
Future<void> _pump(WidgetTester t, Widget scaffold) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: scaffold));
}

/// The padding the body sees.
EdgeInsets _bodyPadding(WidgetTester t) =>
    MediaQuery.paddingOf(t.element(find.byKey(const Key('body'))));

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('the tab bar floats 21 above the bottom, centred', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _tabBar(),
        body: const SizedBox(key: Key('body')),
      ),
    );
    final bar = t.getRect(find.byType(GlassTabBar));
    expect(bar.bottom, moreOrLessEquals(874 - 21));
    expect(bar.center.dx, moreOrLessEquals(201));
  }, variant: ios);

  testWidgets('the body is padded clear of the tab bar', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _tabBar(),
        body: const SizedBox(key: Key('body')),
      ),
    );
    expect(_bodyPadding(t).bottom, 21 + 62);
  }, variant: ios);

  testWidgets('the body fills the screen behind the bars', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        navigationBar: const GlassNavigationBar(title: Text('Inbox')),
        tabBar: _tabBar(),
        body: const SizedBox.expand(key: Key('body')),
      ),
    );
    expect(
      t.getRect(find.byKey(const Key('body'))),
      Offset.zero & const Size(402, 874),
    );
    // The navigation bar's height is added to the status bar.
    expect(_bodyPadding(t).top, greaterThan(62));
  }, variant: ios);

  testWidgets('an accessory sits above the tab bar and pads the body', (
    t,
  ) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _tabBar(),
        bottomAccessory: const GlassBottomAccessory(child: Text('Playing')),
        body: const SizedBox(key: Key('body')),
      ),
    );
    final bar = t.getRect(find.byType(GlassTabBar));
    final accessory = t.getRect(find.byType(GlassBottomAccessory));
    expect(accessory.bottom, moreOrLessEquals(bar.top - 8));
    expect(accessory.height, 48);
    expect(_bodyPadding(t).bottom, 21 + 62 + 8 + 48);
  }, variant: ios);

  testWidgets('the body is a backdrop source unless turned off', (t) async {
    shaderEnv();
    await _pump(t, const GlassScaffold(body: SizedBox()));
    expect(find.byType(GlassBackdropSource), findsOneWidget);
    await _pump(
      t,
      const GlassScaffold(sampleBackdrop: false, body: SizedBox()),
    );
    expect(find.byType(GlassBackdropSource), findsNothing);
  }, variant: ios);

  testWidgets('without a home indicator the bar keeps a small gap', (t) async {
    shaderEnv();
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    t.view.padding = FakeViewPadding.zero;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: GlassScaffold(tabBar: _tabBar(), body: const SizedBox()),
      ),
    );
    expect(
      t.getRect(find.byType(GlassTabBar)).bottom,
      moreOrLessEquals(874 - 8),
    );
  }, variant: ios);

  testWidgets('Material: the same layout with Material bars', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        navigationBar: const GlassNavigationBar(title: Text('Inbox')),
        tabBar: _tabBar(),
        body: const SizedBox(key: Key('body')),
      ),
    );
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(_bodyPadding(t).bottom, 21 + 62);
  }, variant: android);

  testWidgets('the sampled backdrop includes the page colour', (t) async {
    shaderEnv();
    await _pump(
      t,
      const GlassScaffold(backgroundColor: Colors.white, body: SizedBox()),
    );
    final source = find.byType(GlassBackdropSource);
    final page = find.descendant(
      of: source,
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == Colors.white,
      ),
    );
    expect(page, findsOneWidget);
  }, variant: ios);

  testWidgets('with an accessory the tab bar widens to its width', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _tabBar(),
        bottomAccessory: const GlassBottomAccessory(child: Text('Playing')),
        body: const SizedBox(),
      ),
    );
    final bar = t.getRect(find.byType(GlassTabBar));
    final accessory = t.getRect(find.byType(GlassBottomAccessory));
    expect(bar.left, moreOrLessEquals(accessory.left));
    expect(bar.width, moreOrLessEquals(accessory.width));
    expect(accessory.width, moreOrLessEquals(402 - 2 * 21));
  }, variant: ios);

  testWidgets('with an accessory the accessory follows the tab bar glass', (
    t,
  ) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _tabBar(),
        bottomAccessory: const GlassBottomAccessory(child: Text('Playing')),
        body: const SizedBox(),
      ),
    );
    final theme = LiquidGlassTheme.of(t.element(find.text('Playing')));
    expect(theme.defaultMode, GlassRenderMode.shader);
  }, variant: ios);
}
