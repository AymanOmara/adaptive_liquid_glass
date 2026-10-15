import 'dart:math' as math;

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

Widget _row(
  String name,
  List<String> log, {
  bool fullSwipe = true,
  Object? groupTag,
}) => GlassSwipeActions(
  key: ValueKey(name),
  allowsFullSwipe: fullSwipe,
  groupTag: groupTag,
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
    SwipeMetrics.compactIconWidth +
    SwipeMetrics.compactIconGap +
    (13.0 + SwipeMetrics.label.letterSpacing!) * widest.length +
    (SwipeMetrics.compactPadding - SwipeMetrics.compactLabelBearing) * 2;

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

  testWidgets('a slow pull past the full-swipe point only opens', (t) async {
    shaderEnv();
    final log = <String>[];
    await t.pumpWidget(_list(log));
    // About 130 pt/s, to 0.77 of the width.
    await t.timedDrag(
      _rowOf('A'),
      const Offset(-616, 0),
      const Duration(milliseconds: 4700),
    );
    await t.pumpAndSettle();
    expect(log, isEmpty);
    expect(_shift(t, 'A'), moreOrLessEquals(-_trailing, epsilon: 0.01));
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
    // 8 to the label's ink, which starts below its line box's top.
    expect(
      label.top - capsule.bottom,
      moreOrLessEquals(8 - SwipeMetrics.labelInkTop),
    );
    expect(label.center.dx, moreOrLessEquals(capsule.center.dx));
  }, variant: ios);

  group('W11', () {
    Widget confirmList(
      List<String> log, {
      required bool answer,
      double threshold = SwipeMetrics.fullSwipe,
    }) => MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            GlassSwipeActions(
              key: const ValueKey('A'),
              fullSwipeThreshold: threshold,
              trailing: [
                GlassSwipeAction(
                  icon: CupertinoIcons.trash,
                  label: 'Delete',
                  confirm: () async {
                    log.add('confirm');
                    return answer;
                  },
                  onPressed: () => log.add('delete'),
                ),
              ],
              child: const SizedBox(
                height: 60,
                child: Center(child: Text('A')),
              ),
            ),
          ],
        ),
      ),
    );

    testWidgets('a declined confirm keeps the row and skips the action', (
      t,
    ) async {
      shaderEnv();
      final log = <String>[];
      await t.pumpWidget(confirmList(log, answer: false));
      await t.timedDrag(
        _rowOf('A'),
        const Offset(-600, 0),
        const Duration(milliseconds: 600),
      );
      await t.pumpAndSettle();
      expect(log, ['confirm']);
      expect(_shift(t, 'A'), 0);
    }, variant: ios);

    testWidgets('an accepted confirm runs the action, also from a tap', (
      t,
    ) async {
      shaderEnv();
      final log = <String>[];
      await t.pumpWidget(confirmList(log, answer: true));
      await t.timedDrag(
        _rowOf('A'),
        const Offset(-150, 0),
        const Duration(milliseconds: 400),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(log, ['confirm', 'delete']);
      expect(_shift(t, 'A'), 0);
    }, variant: ios);

    testWidgets('fullSwipeThreshold moves the full-swipe point', (t) async {
      shaderEnv();
      final log = <String>[];
      await t.pumpWidget(confirmList(log, answer: true, threshold: 0.9));
      await t.timedDrag(
        _rowOf('A'),
        const Offset(-600, 0),
        const Duration(milliseconds: 600),
      );
      await t.pumpAndSettle();
      // 600 of 800 is short of 0.9: the row only opens.
      expect(log, isEmpty);
      expect(_shift(t, 'A'), lessThan(0));
    }, variant: ios);

    testWidgets('closeAll closes the open row', (t) async {
      shaderEnv();
      await t.pumpWidget(_list([]));
      await t.timedDrag(
        _rowOf('A'),
        const Offset(-200, 0),
        const Duration(milliseconds: 400),
      );
      await t.pumpAndSettle();
      expect(_shift(t, 'A'), lessThan(0));
      GlassSwipeActions.closeAll();
      await t.pumpAndSettle();
      expect(_shift(t, 'A'), 0);
    }, variant: ios);
  });

  group('groupTag', () {
    /// Rows A and B tagged [ab], C and D tagged [cd].
    Widget tagged({Object? ab = 'ab', Object? cd = 'cd'}) => MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            _row('A', [], groupTag: ab),
            _row('B', [], groupTag: ab),
            _row('C', [], groupTag: cd),
            _row('D', [], groupTag: cd),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );

    Future<void> open(WidgetTester t, String name) async {
      await t.timedDrag(
        _rowOf(name),
        const Offset(-200, 0),
        const Duration(milliseconds: 400),
      );
      await t.pumpAndSettle();
    }

    testWidgets('opening a row closes only its own group', (t) async {
      shaderEnv();
      await t.pumpWidget(tagged());
      await open(t, 'A');
      await open(t, 'C');
      expect(_shift(t, 'A'), lessThan(0));
      expect(_shift(t, 'C'), lessThan(0));
      await open(t, 'B');
      expect(_shift(t, 'A'), 0);
      expect(_shift(t, 'B'), lessThan(0));
      expect(_shift(t, 'C'), lessThan(0));
    }, variant: ios);

    testWidgets('closeGroup closes that group only', (t) async {
      shaderEnv();
      await t.pumpWidget(tagged());
      await open(t, 'A');
      await open(t, 'C');
      GlassSwipeActions.closeGroup('cd');
      await t.pumpAndSettle();
      expect(_shift(t, 'C'), 0);
      expect(_shift(t, 'A'), lessThan(0));
    }, variant: ios);

    testWidgets('closeAll closes every group', (t) async {
      shaderEnv();
      await t.pumpWidget(tagged());
      await open(t, 'A');
      await open(t, 'C');
      GlassSwipeActions.closeAll();
      await t.pumpAndSettle();
      expect(_shift(t, 'A'), 0);
      expect(_shift(t, 'C'), 0);
    }, variant: ios);

    testWidgets('a tagged row leaves untagged rows open', (t) async {
      shaderEnv();
      await t.pumpWidget(tagged(ab: null));
      await open(t, 'A');
      await open(t, 'C');
      expect(_shift(t, 'A'), lessThan(0));
      expect(_shift(t, 'C'), lessThan(0));
      // Untagged rows still close each other.
      await open(t, 'B');
      expect(_shift(t, 'A'), 0);
    }, variant: ios);

    testWidgets('a row that changes group closes, then joins it', (t) async {
      shaderEnv();
      await t.pumpWidget(tagged());
      await open(t, 'A');
      await t.pumpWidget(tagged(ab: 'cd'));
      await t.pumpAndSettle();
      expect(_shift(t, 'A'), 0);
      await open(t, 'A');
      await open(t, 'C');
      expect(_shift(t, 'A'), 0);
    }, variant: ios);
  });

  group('native motion', () {
    Widget rows(
      double height, {
      List<String>? log,
      bool destructive = false,
      bool two = false,
      Brightness brightness = Brightness.dark,
    }) => MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: ListView(
          children: [
            GlassSwipeActions(
              key: const ValueKey('A'),
              trailing: [
                GlassSwipeAction(
                  icon: CupertinoIcons.trash,
                  label: 'Delete',
                  destructive: destructive,
                  onPressed: () => log?.add('delete'),
                ),
                if (two)
                  GlassSwipeAction(
                    icon: CupertinoIcons.share,
                    label: 'Share',
                    onPressed: () {},
                  ),
              ],
              child: SizedBox(
                height: height,
                child: const Center(child: Text('A')),
              ),
            ),
            const SizedBox(key: ValueKey('next'), height: 60),
          ],
        ),
      ),
    );

    List<Rect> capsules(WidgetTester t) => [
      for (final e
          in find
              .descendant(
                of: find.byType(SwipeActionButton),
                matching: find.byType(DecoratedBox),
              )
              .evaluate())
        t.getRect(find.byWidget(e.widget)),
    ];

    /// Holds row A dragged [dx] to the left (past the touch slop).
    Future<TestGesture> dragTo(WidgetTester t, double dx) async {
      final g = await t.startGesture(t.getCenter(_rowOf('A')));
      await g.moveBy(const Offset(-20, 0));
      await t.pump();
      // Twice: the first move also takes up the drag's slack.
      for (var i = 0; i < 2; i++) {
        await g.moveBy(Offset(-(dx + _shift(t, 'A')), 0));
        await t.pump();
      }
      return g;
    }

    /// Moves to [dx] and waits out the actions' lag behind the offset.
    Future<void> moveTo(WidgetTester t, TestGesture g, double dx) async {
      await g.moveBy(Offset(-(dx + _shift(t, 'A')), 0));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
    }

    testWidgets('a 110-pt row: a 50-pt circle centred with its label', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(rows(110));
      await t.timedDrag(
        _rowOf('A'),
        const Offset(-120, 0),
        const Duration(milliseconds: 400),
      );
      await t.pumpAndSettle();
      final c = capsules(t).single;
      final row = t.getRect(_rowOf('A'));
      expect(c.width, moreOrLessEquals(50));
      expect(c.height, moreOrLessEquals(50));
      expect(c.top - row.top, moreOrLessEquals((110 - 71.4) / 2));
      expect(800 - c.right, moreOrLessEquals(SwipeMetrics.gap));
      // The label is centred under it.
      expect(
        t.getCenter(find.text('Delete')).dx,
        moreOrLessEquals(c.center.dx),
      );
      // Open: the circle and a gap either side.
      expect(_shift(t, 'A'), moreOrLessEquals(-(50 + 2 * SwipeMetrics.gap)));
    }, variant: ios);

    testWidgets('actions grow in place, the outer first', (t) async {
      shaderEnv();
      await t.pumpWidget(rows(110, two: true));
      final g = await dragTo(t, 40);
      expect(capsules(t), isEmpty);
      await moveTo(t, g, 65); // the outer is growing
      var shown = capsules(t);
      expect(shown, hasLength(1));
      expect(shown.single.width, inExclusiveRange(0, 50));
      // At its resting centre, not following the row.
      const restCentre = 800 - SwipeMetrics.gap - 25;
      expect(shown.single.center.dx, moreOrLessEquals(restCentre));
      await moveTo(t, g, 125); // both
      shown = capsules(t);
      expect(shown, hasLength(2));
      await g.up();
      await t.pumpAndSettle();
    }, variant: ios);

    testWidgets('past rest the outer action stretches; the inner keeps to '
        'the row', (t) async {
      shaderEnv();
      await t.pumpWidget(rows(110, two: true));
      final g = await dragTo(t, 200);
      await t.pump(const Duration(milliseconds: 300));
      final shown = capsules(t)..sort((a, b) => a.left.compareTo(b.left));
      final rowEdge = 800 - 200;
      expect(shown.first.left, moreOrLessEquals(rowEdge + SwipeMetrics.gap));
      expect(shown.first.width, moreOrLessEquals(50));
      expect(shown.last.width, greaterThan(50));
      expect(800 - shown.last.right, moreOrLessEquals(SwipeMetrics.gap));
      await g.up();
      await t.pumpAndSettle();
    }, variant: ios);

    testWidgets('the platter fades in on its own clock, never grey', (t) async {
      shaderEnv();
      await t.pumpWidget(rows(60, brightness: Brightness.light));
      final g = await dragTo(t, 30);
      Color platter() =>
          (t
                      .widget<DecoratedBox>(
                        find
                            .ancestor(
                              of: find.text('A'),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as ShapeDecoration)
              .color!;
      await t.pump(const Duration(milliseconds: 150));
      final mid = platter();
      // 1 - e^-1 of the way after one time constant, the offset unchanged.
      expect(mid.a, moreOrLessEquals(0.63, epsilon: 0.05));
      final full = CupertinoColors.systemGrey5.color;
      expect(mid.r, moreOrLessEquals(full.r, epsilon: 0.001));
      expect(mid.g, moreOrLessEquals(full.g, epsilon: 0.001));
      await g.up();
      await t.pumpAndSettle();
    }, variant: ios);

    testWidgets('it springs open without overshoot', (t) async {
      shaderEnv();
      await t.pumpWidget(rows(110));
      final g = await dragTo(t, 50);
      await g.up();
      var furthest = 0.0;
      for (var i = 0; i < 60; i++) {
        await t.pump(const Duration(milliseconds: 16));
        furthest = math.min(furthest, _shift(t, 'A'));
      }
      expect(
        furthest,
        greaterThanOrEqualTo(-(50 + 2 * SwipeMetrics.gap) - 0.01),
      );
    }, variant: ios);

    testWidgets('closing shrinks and fades the actions from the tap', (
      t,
    ) async {
      shaderEnv();
      await t.pumpWidget(rows(110));
      await t.timedDrag(
        _rowOf('A'),
        const Offset(-120, 0),
        const Duration(milliseconds: 400),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('A'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      // The row is still well open, but the circle is already shrinking.
      expect(_shift(t, 'A'), lessThan(-20));
      expect(capsules(t).single.width, lessThan(40));
      await t.pumpAndSettle();
      expect(capsules(t), isEmpty);
    }, variant: ios);

    testWidgets('an action bounces past full size as it reaches it', (t) async {
      shaderEnv();
      await t.pumpWidget(rows(110));
      final g = await t.startGesture(t.getCenter(_rowOf('A')));
      await g.moveBy(const Offset(-20, 0));
      await t.pump();
      var peak = 0.0;
      // A quick swipe let go short of rest: the row springs open and
      // the circle runs on to full size.
      for (var i = 0; i < 4; i++) {
        await g.moveBy(const Offset(-12, 0));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 16));
        final c = capsules(t);
        if (c.isNotEmpty && c.single.width > peak) peak = c.single.width;
      }
      expect(peak, greaterThan(50 * 1.005));
      expect(peak, lessThan(50 * 1.06));
      await t.pumpAndSettle();
      expect(capsules(t).single.width, moreOrLessEquals(50));
    }, variant: ios);

    testWidgets('a destructive full swipe collapses the row, then runs', (
      t,
    ) async {
      shaderEnv();
      final log = <String>[];
      await t.pumpWidget(rows(60, log: log, destructive: true));
      final top = t.getRect(find.byKey(const ValueKey('next'))).top;
      await t.timedDrag(
        _rowOf('A'),
        const Offset(-600, 0),
        const Duration(milliseconds: 600),
      );
      // Mid collapse the next row has moved up.
      for (var i = 0; i < 20 && log.isEmpty; i++) {
        await t.pump(const Duration(milliseconds: 16));
        if (t.getRect(find.byKey(const ValueKey('next'))).top < top - 1) break;
      }
      expect(t.getRect(find.byKey(const ValueKey('next'))).top, lessThan(top));
      await t.pumpAndSettle();
      expect(log, ['delete']);
      // The app kept the item: the row comes back, shut.
      expect(t.getRect(find.byKey(const ValueKey('next'))).top, top);
      expect(_shift(t, 'A'), 0);
    }, variant: ios);
  });
}
