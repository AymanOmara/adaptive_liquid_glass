import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
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
  const _Harness(this.picks);

  final List<int> picks;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => GlassTabBar(
    items: _items,
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

  for (final (name, variant) in [('shader', ios), ('Material', android)]) {
    testWidgets('$name: the selected tab is tinted, the others are not', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(plainHost(_Harness(_picks())));
      expect(_labelColor(t, 'History'), _blue);
      expect(_labelColor(t, 'Snippets'), isNot(_blue));
      expect(_lens, findsNothing);
    }, variant: variant);

    testWidgets('$name: tapping a tab selects it', (t) async {
      shaderEnv();
      final picks = <int>[];
      await t.pumpWidget(plainHost(_Harness(picks)));
      await t.tap(find.text('Settings'));
      await t.pumpAndSettle();
      expect(picks, [2]);
      expect(_labelColor(t, 'Settings'), _blue);
    }, variant: variant);

    testWidgets('$name: holding shows the lens; dragging picks on release', (
      t,
    ) async {
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
    }, variant: variant);
  }

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
}
