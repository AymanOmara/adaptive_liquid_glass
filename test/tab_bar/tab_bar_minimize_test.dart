import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/scaffold/tab_bar_scroll_edge.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/tab_bar_minimize_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, MaterialApp;
import 'package:flutter_test/flutter_test.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Widget _app({
  required GlassTabBarMinimizeBehavior behavior,
  Widget? body,
  bool accessory = false,
}) => MaterialApp(
  home: GlassScaffold(
    backgroundColor: Colors.white,
    tabBar: GlassTabBar(
      items: const [
        GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
        GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
      ],
      selectedIndex: 0,
      onSelected: (_) {},
      minimizeBehavior: behavior,
    ),
    bottomAccessory: accessory
        ? const GlassBottomAccessory(child: Text('Playing'))
        : null,
    body:
        body ??
        ListView(
          children: [
            for (var i = 0; i < 60; i++)
              SizedBox(height: 44, child: Text('Row $i')),
          ],
        ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));

  test('minimizes after 75 pt down, expands near the top', () {
    final c = TabBarMinimizeController();
    c.scrolled(0, 0);
    c.scrolled(70, 0);
    expect(c.minimized, isFalse);
    c.scrolled(80, 0);
    expect(c.minimized, isTrue);
    c.scrolled(30, 0);
    expect(c.minimized, isTrue, reason: 'scrolling up keeps it minimized');
    c.scrolled(10, 0);
    expect(c.minimized, isFalse, reason: 'near the top it expands');
  });

  test('after a tap expands it, 75 pt more down minimizes again', () {
    final c = TabBarMinimizeController()
      ..scrolled(0, 0)
      ..scrolled(300, 0);
    expect(c.minimized, isTrue);
    c.expand();
    expect(c.minimized, isFalse);
    c.scrolled(350, 0);
    expect(c.minimized, isFalse);
    c.scrolled(380, 0);
    expect(c.minimized, isTrue);
  });

  testWidgets('onScrollDown shrinks the bar; a tap brings it back', (t) async {
    await t.pumpWidget(
      _app(behavior: GlassTabBarMinimizeBehavior.onScrollDown),
    );
    expect(find.text('Settings'), findsOneWidget);
    await t.drag(find.text('Row 3'), const Offset(0, -200));
    await t.pumpAndSettle();
    // Minimized: only the selected tab, as a button.
    expect(find.text('Settings'), findsNothing);
    expect(find.bySemanticsLabel('Home'), findsOneWidget);
    // The icon ignores pointers; the circle under it takes the tap.
    await t.tap(find.byIcon(CupertinoIcons.house_fill), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  }, variant: _ios);

  testWidgets('minimized, the accessory sits beside the circle', (t) async {
    await t.pumpWidget(
      _app(behavior: GlassTabBarMinimizeBehavior.onScrollDown, accessory: true),
    );
    final above = t.getRect(find.byType(GlassBottomAccessory));
    expect(above.left, 21);
    await t.drag(find.text('Row 3'), const Offset(0, -200));
    await t.pumpAndSettle();
    final beside = t.getRect(find.byType(GlassBottomAccessory));
    final width = t.getSize(find.byType(GlassScaffold)).width;
    expect(beside.left, 84);
    expect(beside.right, width - 30);
    expect(beside.height, 48);
    expect(beside.top, greaterThan(above.bottom), reason: 'in the bar row');
  }, variant: _ios);

  testWidgets('the default keeps the bar while scrolling', (t) async {
    await t.pumpWidget(_app(behavior: GlassTabBarMinimizeBehavior.automatic));
    await t.drag(find.text('Row 3'), const Offset(0, -200));
    await t.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  }, variant: _ios);

  testWidgets('a scrolling body gets the tab bar scroll edge', (t) async {
    await t.pumpWidget(_app(behavior: GlassTabBarMinimizeBehavior.automatic));
    await t.pump();
    await t.pump();
    expect(find.byType(TabBarScrollEdge), findsOneWidget);
  }, variant: _ios);

  testWidgets('a still body gets no scroll edge', (t) async {
    await t.pumpWidget(
      _app(
        behavior: GlassTabBarMinimizeBehavior.automatic,
        body: const SizedBox.expand(),
      ),
    );
    await t.pump();
    expect(find.byType(TabBarScrollEdge), findsNothing);
  }, variant: _ios);
}
