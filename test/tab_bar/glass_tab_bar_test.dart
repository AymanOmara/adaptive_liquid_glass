import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Badge, NavigationBar;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _items = [
  GlassTabBarItem(icon: CupertinoIcons.clock_fill, label: 'History'),
  GlassTabBarItem(icon: CupertinoIcons.text_quote, label: 'Snippets'),
  GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
];

const _blue = Color(0xFF0000FF);

/// A tab bar that keeps its own selection, and records every pick.
class _Harness extends StatefulWidget {
  const _Harness(this.picks, {this.items = _items});

  final List<int> picks;
  final List<GlassTabBarItem> items;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => GlassTabBar(
    items: widget.items,
    selectedIndex: _selected,
    selectedColor: _blue,
    onSelected: (i) {
      widget.picks.add(i);
      setState(() => _selected = i);
    },
  );
}

/// A fresh, growable record of picks.
List<int> _picks() => <int>[];

Color? _labelColor(WidgetTester t, String label) =>
    t.widget<Text>(find.text(label).first).style?.color;

/// The clear glass lens is shown only while the bar is held.
Finder get _lens =>
    find.byWidgetPredicate((w) => w is LiquidGlass && w.glass == Glass.clear);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  for (final (name, variant, host) in [
    ('shader', ios, plainHost),
    ('Material', android, (Widget w) => appHost(w)),
  ]) {
    testWidgets('$name: the selected tab is tinted, the others are not', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(host(_Harness(_picks())));
      expect(_labelColor(t, 'History'), _blue);
      expect(_labelColor(t, 'Snippets'), isNot(_blue));
      expect(_lens, findsNothing);
    }, variant: variant);

    testWidgets('$name: tapping a tab selects it', (t) async {
      shaderEnv();
      final picks = <int>[];
      await t.pumpWidget(host(_Harness(picks)));
      await t.tap(find.text('Settings'));
      await t.pumpAndSettle();
      expect(picks, [2]);
      expect(_labelColor(t, 'Settings'), _blue);
    }, variant: variant);
  }

  testWidgets('holding shows the lens; dragging picks on release', (t) async {
    shaderEnv();
    final picks = <int>[];
    await t.pumpWidget(plainHost(_Harness(picks)));
    final from = t.getCenter(find.text('History'));
    final to = t.getCenter(find.text('Settings'));
    final gesture = await t.startGesture(from);
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(_lens, findsOneWidget);
    for (var i = 1; i <= 10; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 10)!);
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(picks, isEmpty, reason: 'nothing is picked while held');
    await gesture.up();
    await t.pumpAndSettle();
    expect(picks, [2]);
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('right to left: the first tab is on the right', (t) async {
    shaderEnv();
    final picks = <int>[];
    await t.pumpWidget(
      plainHost(_Harness(picks), direction: TextDirection.rtl),
    );
    expect(
      t.getCenter(find.text('History')).dx,
      greaterThan(t.getCenter(find.text('Settings')).dx),
    );
    await t.tap(find.text('Settings'));
    await t.pumpAndSettle();
    expect(picks, [2]);
  }, variant: ios);

  testWidgets('each tab is a selectable button for assistive tech', (t) async {
    shaderEnv();
    final semantics = t.ensureSemantics();
    final picks = <int>[];
    await t.pumpWidget(plainHost(_Harness(picks)));
    expect(
      t.getSemantics(find.text('History')),
      matchesSemantics(
        label: 'History',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    expect(
      t.getSemantics(find.text('Snippets')),
      matchesSemantics(
        label: 'Snippets',
        isButton: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    t.semantics.tap(find.semantics.byLabel('Snippets'));
    await t.pumpAndSettle();
    expect(picks, [1]);
    semantics.dispose();
  }, variant: ios);

  testWidgets('Reduce Motion: the pill jumps instead of sliding', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _Harness(_picks()),
          ),
        ),
      ),
    );
    await t.tap(find.text('Settings'));
    await t.pump();
    // One frame later the pill is already under Settings: no spring.
    final pill = find.byWidgetPredicate(
      (w) => w is DecoratedBox && w.decoration is ShapeDecoration,
    );
    expect(
      t.getCenter(pill).dx,
      moreOrLessEquals(t.getCenter(find.text('Settings')).dx, epsilon: 0.5),
    );
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('five tabs shrink to fit a phone instead of overflowing', (
    t,
  ) async {
    shaderEnv();
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final picks = <int>[];
    final five = [
      for (final l in ['A', 'B', 'C', 'D', 'E'])
        GlassTabBarItem(icon: CupertinoIcons.circle, label: l),
    ];
    await t.pumpWidget(plainHost(_Harness(picks, items: five)));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byType(GlassTabBar)).width, lessThanOrEqualTo(402));
    // (402 - 2 × 4 inset - 7.55 pill) / 5 tabs, not the 86.15 that would
    // overflow.
    expect(
      t.getCenter(find.text('E')).dx - t.getCenter(find.text('D')).dx,
      moreOrLessEquals(77.29, epsilon: 0.01),
    );
    await t.tap(find.text('E'));
    await t.pumpAndSettle();
    expect(picks, [4]);
    expect(_labelColor(t, 'E'), _blue);
  }, variant: ios);

  testWidgets('three tabs keep their full width when there is room', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_Harness(_picks())));
    expect(
      t.getSize(find.byType(GlassTabBar)).width,
      moreOrLessEquals(3 * 86.15 + 7.55 + 8, epsilon: 0.01),
    );
  }, variant: ios);

  testWidgets('the selected tab shows its active icon', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        _Harness(
          _picks(),
          items: const [
            GlassTabBarItem(
              icon: CupertinoIcons.house,
              activeIcon: CupertinoIcons.house_fill,
              label: 'Home',
            ),
            GlassTabBarItem(
              icon: CupertinoIcons.person,
              activeIcon: CupertinoIcons.person_fill,
              label: 'Me',
            ),
          ],
        ),
      ),
    );
    expect(find.byIcon(CupertinoIcons.house_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.person), findsOneWidget);
    await t.tap(find.text('Me'));
    await t.pumpAndSettle();
    expect(find.byIcon(CupertinoIcons.house), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.person_fill), findsOneWidget);
  }, variant: ios);

  testWidgets('a badge shows its text and is read with the tab', (t) async {
    shaderEnv();
    final semantics = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(
        _Harness(
          _picks(),
          items: const [
            GlassTabBarItem(
              icon: CupertinoIcons.mail,
              label: 'Mail',
              badge: '3',
            ),
            GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
          ],
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(
      t.getSemantics(find.text('Mail')),
      matchesSemantics(
        label: 'Mail',
        value: '3',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  }, variant: ios);

  testWidgets('Material: a Material 3 navigation bar, no glass lens', (
    t,
  ) async {
    shaderEnv();
    final picks = <int>[];
    await t.pumpWidget(
      appHost(
        _Harness(
          picks,
          items: const [
            GlassTabBarItem(
              icon: CupertinoIcons.mail,
              label: 'Mail',
              badge: '3',
            ),
            GlassTabBarItem(
              icon: CupertinoIcons.bell,
              label: 'Alerts',
              badge: '',
            ),
            GlassTabBarItem(icon: CupertinoIcons.gear, label: 'Settings'),
          ],
        ),
      ),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNothing);
    expect(find.byType(Badge), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    await t.tap(find.text('Settings'));
    await t.pumpAndSettle();
    expect(picks, [2]);
  }, variant: android);
}
