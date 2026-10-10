import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
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

  testWidgets('a floating action button sits 16 above the bars, at the end', (
    t,
  ) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _tabBar(),
        floatingActionButton: const SizedBox.square(
          key: Key('fab'),
          dimension: 46,
        ),
        body: const SizedBox(key: Key('body')),
      ),
    );
    final fab = t.getRect(find.byKey(const Key('fab')));
    final bar = t.getRect(find.byType(GlassTabBar));
    expect(fab.bottom, moreOrLessEquals(bar.top - 16));
    expect(fab.right, 402 - 16);
    // The body keeps its padding: the button floats over it.
    expect(_bodyPadding(t).bottom, 21 + 62);
  }, variant: ios);

  testWidgets('without bars the button clears the safe area', (t) async {
    shaderEnv();
    await _pump(
      t,
      const GlassScaffold(
        floatingActionButton: SizedBox.square(key: Key('fab'), dimension: 56),
        body: SizedBox(key: Key('body')),
      ),
    );
    expect(t.getRect(find.byKey(const Key('fab'))).bottom, 874 - 34 - 16);
  }, variant: ios);

  testWidgets('Material edge to edge: the button sits 16 above the bar', (
    t,
  ) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: GlassTabBar(
          items: _items,
          selectedIndex: 0,
          onSelected: (_) {},
          materialStyle: GlassMaterialTabBarStyle.edgeToEdge,
        ),
        floatingActionButton: GlassFloatingActionButton.extended(
          onPressed: () {},
          icon: CupertinoIcons.add,
          label: const Text('New event'),
        ),
        body: const SizedBox(key: Key('body')),
      ),
    );
    final fab = t.getRect(find.byType(FloatingActionButton));
    final bar = t.getRect(find.byType(NavigationBar));
    expect(fab.bottom, bar.top - 16);
    expect(fab.right, 402 - 16);
  }, variant: android);

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

  testWidgets('the accessory paints after the tab bar, out of its lens', (
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
    // Children of a Stack paint in order; the tab lens samples only what
    // was painted before it.
    final order = t
        .widgetList(
          find.byWidgetPredicate(
            (w) => w is GlassTabBar || w is GlassBottomAccessory,
          ),
        )
        .map((w) => w.runtimeType)
        .toList();
    expect(order, [GlassTabBar, GlassBottomAccessory]);
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

  testWidgets('Material edge to edge: full width on the bottom edge', (
    t,
  ) async {
    shaderEnv();
    var searched = 0;
    await _pump(
      t,
      GlassScaffold(
        tabBar: GlassTabBar(
          items: _items,
          selectedIndex: 0,
          onSelected: (_) {},
          onSearch: () => searched++,
          materialStyle: GlassMaterialTabBarStyle.edgeToEdge,
        ),
        body: const SizedBox(key: Key('body')),
      ),
    );
    final bar = t.getRect(find.byType(NavigationBar));
    expect(bar.left, 0);
    expect(bar.right, 402);
    expect(bar.bottom, 874);
    // The safe area is inside the bar, and the body clears both.
    expect(bar.height, 62 + 34);
    expect(_bodyPadding(t).bottom, 62 + 34);
    expect(find.byType(ClipPath), findsNothing);
    // The search tab is a last destination.
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    await t.tap(find.text('Search'));
    expect(searched, 1);
  }, variant: android);

  testWidgets('edge to edge leaves the glass bar floating', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: GlassTabBar(
          items: _items,
          selectedIndex: 0,
          onSelected: (_) {},
          materialStyle: GlassMaterialTabBarStyle.edgeToEdge,
        ),
        body: const SizedBox(key: Key('body')),
      ),
    );
    expect(
      t.getRect(find.byType(GlassTabBar)).bottom,
      moreOrLessEquals(874 - 21),
    );
    expect(_bodyPadding(t).bottom, 21 + 62);
  }, variant: ios);

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

  testWidgets('the accessory is drawn in the tab bar\'s material', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        tabBar: _tabBar(),
        bottomAccessory: const GlassBottomAccessory(child: Text('Playing')),
        body: const SizedBox(),
      ),
    );
    final accessory = LiquidGlassTheme.of(
      t.element(find.text('Playing')),
    ).constants.regular;
    final bar = LiquidGlassTheme.of(
      t.element(find.text('History').first),
    ).constants.regular;
    expect(accessory.fillOpacity, bar.fillOpacity);
    expect(accessory.blurSigma, bar.blurSigma);
    expect(accessory.toneKnots, bar.toneKnots);
  }, variant: ios);

  testWidgets('accessory content takes the primary label colour', (t) async {
    shaderEnv();
    await _pump(
      t,
      GlassScaffold(
        backgroundColor: const Color(0xFFFFFFFF),
        tabBar: _tabBar(),
        bottomAccessory: const GlassBottomAccessory(
          child: Row(
            children: [Icon(CupertinoIcons.play_fill), Text('Playing')],
          ),
        ),
        body: const SizedBox(),
      ),
    );
    final text = t.element(find.text('Playing'));
    expect(DefaultTextStyle.of(text).style.color, GlassColors.label.color);
    expect(
      IconTheme.of(t.element(find.byIcon(CupertinoIcons.play_fill))).color,
      GlassColors.label.color,
    );
  }, variant: ios);
}
