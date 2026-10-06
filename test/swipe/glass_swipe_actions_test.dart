import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/swipe/swipe_action_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _row(String name, List<String> log, {bool fullSwipe = true}) =>
    GlassSwipeActions(
      key: ValueKey(name),
      allowsFullSwipe: fullSwipe,
      leading: [
        GlassSwipeAction(
          icon: CupertinoIcons.pin,
          label: 'Pin',
          onPressed: () => log.add('pin $name'),
        ),
      ],
      trailing: [
        GlassSwipeAction(
          icon: CupertinoIcons.trash,
          label: 'Delete',
          color: CupertinoColors.systemRed,
          onPressed: () => log.add('delete $name'),
        ),
        GlassSwipeAction(
          icon: CupertinoIcons.flag,
          label: 'Flag',
          onPressed: () => log.add('flag $name'),
        ),
      ],
      child: SizedBox(height: 60, child: Center(child: Text(name))),
    );

Widget _list(
  List<String> log, {
  TextDirection dir = TextDirection.ltr,
  bool fullSwipe = true,
}) => MaterialApp(
  builder: (c, child) => Directionality(textDirection: dir, child: child!),
  home: Scaffold(
    body: ListView(
      children: [
        _row('A', log, fullSwipe: fullSwipe),
        _row('B', log, fullSwipe: fullSwipe),
        const SizedBox(height: 2000),
      ],
    ),
  ),
);

Finder _rowOf(String name) => find.byKey(ValueKey(name));

double _shift(WidgetTester t, String name) =>
    t.getRect(find.text(name)).center.dx - 400;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a short swipe left opens the trailing actions', (t) async {
    shaderEnv();
    final log = <String>[];
    await t.pumpWidget(_list(log));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(-120, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    // Two actions: 2 x 74 + 8.
    expect(_shift(t, 'A'), moreOrLessEquals(-156));
    expect(find.text('Delete'), findsOneWidget);
    // The first action is outermost.
    expect(
      t.getCenter(find.text('Delete')).dx,
      greaterThan(t.getCenter(find.text('Flag')).dx),
    );
    await t.tap(find.text('Flag'));
    await t.pumpAndSettle();
    expect(log, ['flag A']);
    expect(_shift(t, 'A'), 0);
  }, variant: ios);

  testWidgets('a tiny swipe springs back shut', (t) async {
    shaderEnv();
    await t.pumpWidget(_list([]));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(-40, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), 0);
    expect(find.byType(SwipeActionButton), findsNothing);
  }, variant: ios);

  testWidgets('a full swipe runs the first action, with a haptic', (t) async {
    shaderEnv();
    final log = <String>[];
    final haptics = <Object?>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    await t.pumpWidget(_list(log));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(-600, 0),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(log, ['delete A']);
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  }, variant: ios);

  testWidgets('without full swipe it rubber-bands and only opens', (t) async {
    shaderEnv();
    final log = <String>[];
    await t.pumpWidget(_list(log, fullSwipe: false));
    final g = await t.startGesture(t.getCenter(_rowOf('A')));
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-400, 0));
    await t.pump();
    // Past 156 the row moves at 0.3 of the finger.
    expect(_shift(t, 'A'), greaterThan(-156 - 0.3 * 300));
    await g.up();
    await t.pumpAndSettle();
    expect(log, isEmpty);
    expect(_shift(t, 'A'), moreOrLessEquals(-156));
  }, variant: ios);

  testWidgets('a swipe right opens the leading actions', (t) async {
    shaderEnv();
    await t.pumpWidget(_list([]));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(100, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), moreOrLessEquals(82));
    expect(find.text('Pin'), findsOneWidget);
    expect(t.getCenter(find.text('Pin')).dx, lessThan(82));
  }, variant: ios);

  testWidgets('right to left: trailing actions are on the left', (t) async {
    shaderEnv();
    await t.pumpWidget(_list([], dir: TextDirection.rtl));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(120, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), moreOrLessEquals(156));
    expect(
      t.getCenter(find.text('Delete')).dx,
      lessThan(t.getCenter(find.text('Flag')).dx),
    );
  }, variant: ios);

  testWidgets('tapping the open row, or opening another, closes it', (t) async {
    shaderEnv();
    await t.pumpWidget(_list([]));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(-120, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('A'));
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), 0);
    await t.timedDrag(
      _rowOf('A'),
      const Offset(-120, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    await t.timedDrag(
      _rowOf('B'),
      const Offset(-120, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), 0);
    expect(_shift(t, 'B'), moreOrLessEquals(-156));
  }, variant: ios);

  testWidgets('scrolling closes an open row', (t) async {
    shaderEnv();
    await t.pumpWidget(_list([]));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(-120, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    await t.drag(find.byType(ListView), const Offset(0, -30));
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), 0);
  }, variant: ios);

  testWidgets('assistive tech gets the actions as custom actions', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    final log = <String>[];
    await t.pumpWidget(_list(log));
    final data = t.getSemantics(find.text('A')).getSemanticsData();
    final ids = data.customSemanticsActionIds!;
    final labels = [
      for (final id in ids) CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(labels, containsAll(['Pin', 'Delete', 'Flag']));
    s.dispose();
  }, variant: ios);

  testWidgets('a short row scales its actions down to fit', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              GlassSwipeActions(
                trailing: [
                  GlassSwipeAction(
                    icon: CupertinoIcons.trash,
                    label: 'Delete',
                    onPressed: () {},
                  ),
                ],
                child: const SizedBox(height: 44, child: Text('Short')),
              ),
            ],
          ),
        ),
      ),
    );
    await t.timedDrag(
      find.text('Short'),
      const Offset(-120, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(t.getRect(find.text('Delete')).bottom, lessThanOrEqualTo(44));
  }, variant: ios);
}
