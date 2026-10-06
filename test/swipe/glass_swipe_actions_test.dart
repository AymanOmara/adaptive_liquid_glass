import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/swipe/swipe_action_button.dart';
import 'package:adaptive_liquid_glass/src/swipe/swipe_metrics.dart';
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

/// A compact action's width when [widest] is the side's widest label (the
/// test font draws each character 13 wide at 13 pt, plus the tracking).
double _width(String widest) =>
    SwipeMetrics.compactIconSize +
    SwipeMetrics.compactIconGap +
    (13.0 + SwipeMetrics.label.letterSpacing!) * widest.length +
    SwipeMetrics.compactPadding * 2;

/// How far a row moves to open [n] actions of [width].
double _open(int n, double width) => n * width + (n + 1) * SwipeMetrics.gap;

/// Trailing: Delete and Flag; leading: Pin.
final _trailing = _open(2, _width('Delete'));
final _leading = _open(1, _width('Pin'));

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
      const Offset(-200, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), moreOrLessEquals(-_trailing, epsilon: 0.01));
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
    // Past the actions the row moves at 0.3 of the finger.
    expect(_shift(t, 'A'), greaterThan(-_trailing - 0.3 * 420));
    await g.up();
    await t.pumpAndSettle();
    expect(log, isEmpty);
    expect(_shift(t, 'A'), moreOrLessEquals(-_trailing, epsilon: 0.01));
  }, variant: ios);

  testWidgets('a swipe right opens the leading actions', (t) async {
    shaderEnv();
    await t.pumpWidget(_list([]));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(90, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), moreOrLessEquals(_leading, epsilon: 0.01));
    expect(find.text('Pin'), findsOneWidget);
    expect(t.getCenter(find.text('Pin')).dx, lessThan(_leading));
  }, variant: ios);

  testWidgets('right to left: trailing actions are on the left', (t) async {
    shaderEnv();
    await t.pumpWidget(_list([], dir: TextDirection.rtl));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(200, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), moreOrLessEquals(_trailing, epsilon: 0.01));
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
      const Offset(-200, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('A'));
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), 0);
    await t.timedDrag(
      _rowOf('A'),
      const Offset(-200, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    await t.timedDrag(
      _rowOf('B'),
      const Offset(-200, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    expect(_shift(t, 'A'), 0);
    expect(_shift(t, 'B'), moreOrLessEquals(-_trailing, epsilon: 0.01));
  }, variant: ios);

  testWidgets('scrolling closes an open row', (t) async {
    shaderEnv();
    await t.pumpWidget(_list([]));
    await t.timedDrag(
      _rowOf('A'),
      const Offset(-200, 0),
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

  Widget single(double height) => MaterialApp(
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
            child: SizedBox(height: height, child: const Text('Row')),
          ),
        ],
      ),
    ),
  );

  Rect capsuleOf(WidgetTester t) => t.getRect(
    find.descendant(
      of: find.byType(SwipeActionButton),
      matching: find.byType(DecoratedBox),
    ),
  );

  testWidgets('a short row: icon and label inside a capsule 8 shorter', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(single(54));
    await t.timedDrag(
      find.text('Row'),
      const Offset(-200, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    final capsule = capsuleOf(t);
    final row = t.getRect(find.byType(GlassSwipeActions));
    expect(capsule.height, moreOrLessEquals(54 - 8));
    expect(capsule.top - row.top, moreOrLessEquals(4));
    expect(capsule.width, moreOrLessEquals(_width('Delete'), epsilon: 0.01));
    expect(800 - capsule.right, moreOrLessEquals(SwipeMetrics.gap));
    // The label is inside the capsule.
    expect(capsule.contains(t.getCenter(find.text('Delete'))), isTrue);
  }, variant: ios);

  testWidgets('a tall row: a 60 x 40 capsule with the label below', (t) async {
    shaderEnv();
    await t.pumpWidget(single(72));
    await t.timedDrag(
      find.text('Row'),
      const Offset(-150, 0),
      const Duration(milliseconds: 400),
    );
    await t.pumpAndSettle();
    final capsule = capsuleOf(t);
    final row = t.getRect(find.byType(GlassSwipeActions));
    expect(capsule.size, const Size(60, 40));
    expect(capsule.top - row.top, moreOrLessEquals(4.33));
    final label = t.getRect(find.text('Delete'));
    expect(label.top - capsule.bottom, moreOrLessEquals(8));
    expect(label.center.dx, moreOrLessEquals(capsule.center.dx));
  }, variant: ios);
}
