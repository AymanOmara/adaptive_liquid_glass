import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, MaterialApp;
import 'package:flutter_test/flutter_test.dart';

final _ios = TargetPlatformVariant.only(TargetPlatform.iOS);

Widget _app(ValueChanged<int> onSelected) => MaterialApp(
  home: GlassScaffold(
    backgroundColor: Colors.white,
    tabBar: GlassTabBar(
      items: const [
        GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
        GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
      ],
      selectedIndex: 0,
      onSelected: onSelected,
      style: GlassTabBarStyle.sidebarAdaptable,
    ),
    body: const SizedBox.expand(),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));

  testWidgets('on an iPad the bar is at the top; the sidebar selects', (
    t,
  ) async {
    t.view.physicalSize = const Size(834, 1210);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    var picked = -1;
    await t.pumpWidget(_app((i) => picked = i));
    final home = t.getRect(find.text('Home'));
    expect(home.top, lessThan(60), reason: 'top bar');
    await t.tap(find.bySemanticsLabel('Show Sidebar'));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Hide Sidebar'), findsOneWidget);
    await t.tap(find.text('Settings').last);
    await t.pumpAndSettle();
    expect(picked, 1);
    expect(find.bySemanticsLabel('Hide Sidebar'), findsNothing);
  }, variant: _ios);

  testWidgets('on a phone it stays the bottom bar', (t) async {
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_app((_) {}));
    expect(find.bySemanticsLabel('Show Sidebar'), findsNothing);
    expect(t.getRect(find.text('Home')).top, greaterThan(700));
  }, variant: _ios);
}
