import 'dart:async';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/swiftui_spring.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/refresh/refresh_metrics.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The list under the wrapper: always scrollable with bouncing physics.
Widget get _list => ListView(
  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
  children: List.generate(
    30,
    (i) => SizedBox(height: 40, child: Text('Row $i')),
  ),
);

/// The release's ballistic scroll reports from its second frame: the
/// first tick is at elapsed zero.
const _frame = Duration(milliseconds: 16);

Widget _host(Widget child) =>
    plainHost(SizedBox(width: 300, height: 400, child: child));

/// Pulls the list past the measured threshold (173 pt of overscroll)
/// against the bouncing friction, in 30-pt finger steps, and lets go.
Future<void> _pullPast(WidgetTester t) async {
  final gesture = await t.startGesture(
    t.getCenter(find.byType(Scrollable).first),
  );
  for (var i = 0; i < 30; i++) {
    await gesture.moveBy(const Offset(0, 30));
    await t.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('pull past the threshold calls onRefresh once', (t) async {
    shaderEnv();
    var count = 0;
    final completer = Completer<void>();
    await t.pumpWidget(
      _host(
        GlassRefresh(
          onRefresh: () {
            count++;
            return completer.future;
          },
          child: _list,
        ),
      ),
    );
    await t.pump();
    await _pullPast(t);
    await t.pump();
    await t.pump(_frame);
    expect(count, 1);
    // While the refresh is pending a second pull does not call again.
    await _pullPast(t);
    await t.pump();
    await t.pump(_frame);
    expect(count, 1);
    completer.complete();
    await t.pumpAndSettle();
    expect(count, 1);
  }, variant: ios);

  testWidgets('a short pull does not refresh', (t) async {
    shaderEnv();
    var count = 0;
    await t.pumpWidget(
      _host(
        GlassRefresh(
          onRefresh: () {
            count++;
            return Future<void>.value();
          },
          child: _list,
        ),
      ),
    );
    await t.pump();
    await t.drag(find.text('Row 0'), const Offset(0, 30));
    await t.pump();
    await t.pump(_frame);
    expect(count, 0);
    await t.pumpAndSettle();
    expect(count, 0);
  }, variant: ios);

  testWidgets('the indicator shows while pending and goes after', (t) async {
    shaderEnv();
    final completer = Completer<void>();
    await t.pumpWidget(
      _host(GlassRefresh(onRefresh: () => completer.future, child: _list)),
    );
    await t.pump();
    expect(
      t
          .widget<GlassRefreshIndicator>(find.byType(GlassRefreshIndicator))
          .refreshing,
      isFalse,
    );
    await _pullPast(t);
    await t.pump();
    await t.pump(_frame);
    expect(
      t
          .widget<GlassRefreshIndicator>(find.byType(GlassRefreshIndicator))
          .refreshing,
      isTrue,
    );
    completer.complete();
    await t.pumpAndSettle();
    final done = t.widget<GlassRefreshIndicator>(
      find.byType(GlassRefreshIndicator),
    );
    expect(done.refreshing, isFalse);
    // Exactly 0: a spring stopping just above it left a tiny disk shown.
    expect(done.progress, 0);
  }, variant: ios);

  test("the snap-back is SwiftUI's measured spring (0.47 / 0.77)", () {
    expect(RefreshMetrics.snapResponse, 0.47);
    expect(RefreshMetrics.snapDamping, 0.77);
  });

  testWidgets('the snap-back follows the measured spring', (t) async {
    shaderEnv();
    final completer = Completer<void>();
    await t.pumpWidget(
      _host(GlassRefresh(onRefresh: () => completer.future, child: _list)),
    );
    await t.pump();
    await _pullPast(t);
    await t.pump();
    await t.pump(_frame);
    // The list settles back while the spinner keeps turning.
    await t.pump(const Duration(seconds: 1));
    completer.complete();
    await t.pump();
    const elapsed = Duration(milliseconds: 150);
    await t.pump(elapsed);
    final spring = SpringSimulation(
      swiftUISpring(
        response: RefreshMetrics.snapResponse,
        dampingFraction: RefreshMetrics.snapDamping,
      ),
      1,
      0,
      0,
    );
    final progress = t
        .widget<GlassRefreshIndicator>(find.byType(GlassRefreshIndicator))
        .progress;
    expect(
      progress,
      closeTo(
        spring.x(elapsed.inMicroseconds / Duration.microsecondsPerSecond),
        0.03,
      ),
    );
    await t.pumpAndSettle();
  }, variant: ios);

  /// Where the content's first row sits below the wrapper's top.
  double contentOffset(WidgetTester t) =>
      t.getTopLeft(find.text('Row 0')).dy -
      t.getTopLeft(find.byType(GlassRefresh)).dy;

  testWidgets('the content is held down while the refresh is pending', (
    t,
  ) async {
    shaderEnv();
    final completer = Completer<void>();
    await t.pumpWidget(
      _host(GlassRefresh(onRefresh: () => completer.future, child: _list)),
    );
    await t.pump();
    expect(contentOffset(t), 0);
    await _pullPast(t);
    await t.pump();
    // As the release's bounce returns, the content never rises above
    // the hold: it stops at the spinner's room instead of the top.
    for (var i = 0; i < 60; i++) {
      await t.pump(_frame);
      expect(
        contentOffset(t),
        greaterThanOrEqualTo(RefreshMetrics.indicatorExtent - 0.01),
      );
    }
    await t.pump(const Duration(seconds: 1));
    expect(contentOffset(t), moreOrLessEquals(RefreshMetrics.indicatorExtent));
    // The spinner is shown, turning, within the held room.
    final indicator = t.widget<GlassRefreshIndicator>(
      find.byType(GlassRefreshIndicator),
    );
    expect(indicator.refreshing, isTrue);
    expect(indicator.progress, 1);
    final spinner =
        t.getCenter(find.byType(GlassRefreshIndicator)).dy -
        t.getTopLeft(find.byType(GlassRefresh)).dy;
    expect(spinner, moreOrLessEquals(RefreshMetrics.indicatorExtent / 2));
    completer.complete();
    await t.pumpAndSettle();
    expect(contentOffset(t), 0);
  }, variant: ios);

  testWidgets('the held content returns on the measured spring', (t) async {
    shaderEnv();
    final completer = Completer<void>();
    await t.pumpWidget(
      _host(GlassRefresh(onRefresh: () => completer.future, child: _list)),
    );
    await t.pump();
    await _pullPast(t);
    await t.pump();
    // The release triggers on its next frame; the hold then settles.
    await t.pump(_frame);
    await t.pump(const Duration(seconds: 1));
    completer.complete();
    await t.pump();
    const elapsed = Duration(milliseconds: 150);
    await t.pump(elapsed);
    final spring = SpringSimulation(
      swiftUISpring(
        response: RefreshMetrics.snapResponse,
        dampingFraction: RefreshMetrics.snapDamping,
      ),
      RefreshMetrics.indicatorExtent,
      0,
      0,
    );
    expect(
      contentOffset(t),
      closeTo(
        spring.x(elapsed.inMicroseconds / Duration.microsecondsPerSecond),
        2,
      ),
    );
    await t.pumpAndSettle();
    expect(contentOffset(t), 0);
  }, variant: ios);

  test("the hold settles on SwiftUI's measured spring (0.30 / 1.43)", () {
    expect(RefreshMetrics.holdResponse, 0.30);
    expect(RefreshMetrics.holdDamping, 1.43);
  });

  testWidgets('the release eases into the hold on the measured spring', (
    t,
  ) async {
    shaderEnv();
    final completer = Completer<void>();
    await t.pumpWidget(
      _host(GlassRefresh(onRefresh: () => completer.future, child: _list)),
    );
    await t.pump();
    final gesture = await t.startGesture(t.getCenter(find.text('Row 0')));
    for (var i = 0; i < 24; i++) {
      await gesture.moveBy(const Offset(0, 30));
      await t.pump(_frame);
    }
    // Armed by the finger's travel (UIKit's band in this short viewport
    // stops short of the trigger distance).
    final pulled = contentOffset(t);
    expect(pulled, greaterThan(RefreshMetrics.indicatorExtent + 50));
    await gesture.up();
    await t.pump();
    // The release's ballistic reports on the next frame, which triggers.
    await t.pump(_frame);
    final spring = SpringSimulation(
      swiftUISpring(
        response: RefreshMetrics.holdResponse,
        dampingFraction: RefreshMetrics.holdDamping,
      ),
      pulled,
      RefreshMetrics.indicatorExtent,
      0,
    );
    var frames = 0;
    for (final checkpoint in [5, 10, 20]) {
      for (; frames < checkpoint; frames++) {
        await t.pump(_frame);
      }
      expect(
        contentOffset(t),
        closeTo(spring.x(frames * _frame.inMicroseconds / 1e6), 2),
        reason: '$frames frames',
      );
    }
    completer.complete();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('the spinner sits below the top inset (edgeOffset)', (t) async {
    shaderEnv();
    Future<double> spinnerY(Widget refresh, {double inset = 0}) async {
      await t.pumpWidget(
        plainHost(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: EdgeInsets.only(top: inset)),
              child: SizedBox(width: 300, height: 400, child: refresh),
            ),
          ),
        ),
      );
      await t.pump();
      await _pullPast(t);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      final y =
          t.getCenter(find.byType(GlassRefreshIndicator)).dy -
          t.getTopLeft(find.byType(GlassRefresh)).dy;
      return y;
    }

    final completers = <Completer<void>>[];
    Future<void> pending() {
      final c = Completer<void>();
      completers.add(c);
      return c.future;
    }

    // By default below the media padding, as the list's own padding is.
    expect(
      await spinnerY(GlassRefresh(onRefresh: pending, child: _list), inset: 40),
      moreOrLessEquals(40 + RefreshMetrics.indicatorExtent / 2),
    );
    for (final c in completers) {
      if (!c.isCompleted) c.complete();
    }
    await t.pumpAndSettle();
    expect(
      await spinnerY(
        GlassRefresh(onRefresh: pending, edgeOffset: 50, child: _list),
      ),
      moreOrLessEquals(50 + RefreshMetrics.indicatorExtent / 2),
    );
    for (final c in completers) {
      if (!c.isCompleted) c.complete();
    }
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('a short pull is not held', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(GlassRefresh(onRefresh: () async {}, child: _list)),
    );
    await t.pump();
    await t.drag(find.text('Row 0'), const Offset(0, 30));
    await t.pumpAndSettle();
    expect(contentOffset(t), 0);
  }, variant: ios);

  testWidgets('scrolling into the list while refreshing takes the spinner '
      'along', (t) async {
    shaderEnv();
    final completer = Completer<void>();
    await t.pumpWidget(
      _host(GlassRefresh(onRefresh: () => completer.future, child: _list)),
    );
    await t.pump();
    await _pullPast(t);
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    final top = t.getTopLeft(find.byType(GlassRefresh)).dy;
    final before = t.getCenter(find.byType(GlassRefreshIndicator)).dy - top;
    await t.drag(find.text('Row 3'), const Offset(0, -40));
    // Not pumpAndSettle: the spinner turns until the refresh ends.
    await t.pump(const Duration(seconds: 1));
    final after = t.getCenter(find.byType(GlassRefreshIndicator)).dy - top;
    // The spinner rides up with the content, as UIKit's inset does.
    expect(after, lessThan(before - 20));
    completer.complete();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('Android uses Material RefreshIndicator', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        SizedBox(
          width: 300,
          height: 400,
          child: GlassRefresh(onRefresh: () async {}, child: _list),
        ),
      ),
    );
    await t.pump();
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(find.byType(GlassRefreshIndicator), findsNothing);
  }, variant: android);

  testWidgets('Reduce Motion: the refreshing spinner does not turn', (t) async {
    shaderEnv();
    final completer = Completer<void>();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: SizedBox(
              width: 300,
              height: 400,
              child: GlassRefresh(
                onRefresh: () => completer.future,
                child: _list,
              ),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await _pullPast(t);
    await t.pump();
    final spinner = t.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );
    expect(spinner.animating, isFalse);
    completer.complete();
    await t.pumpAndSettle();
  }, variant: ios);

  test('threshold and spinner are the measured ones', () {
    // SwiftUI's .refreshable (iOS 26.4): pulls of up to 170.6 pt did not
    // refresh, 174.7 did; the spinner is 30 pt across.
    expect(RefreshMetrics.triggerDistance, 173);
    expect(RefreshMetrics.triggerTravel, 315);
    expect(RefreshMetrics.spinnerSize, 30);
  });

  testWidgets('the refresh starts under the finger at the threshold', (
    t,
  ) async {
    shaderEnv();
    var count = 0;
    final completer = Completer<void>();
    final controller = ScrollController();
    await t.pumpWidget(
      _host(
        GlassRefresh(
          onRefresh: () {
            count++;
            return completer.future;
          },
          child: ListView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            children: List.generate(
              30,
              (i) => SizedBox(height: 40, child: Text('Row $i')),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    final gesture = await t.startGesture(
      t.getCenter(find.byType(Scrollable).first),
    );
    var moved = 0.0;
    for (var i = 0; i < 400 && count == 0; i++) {
      await gesture.moveBy(const Offset(0, 5));
      moved += 5;
      await t.pump(_frame);
    }
    // Finger still down: it started on the move that passed UIKit's
    // threshold, 173 pt of overscroll or (Flutter's friction holding the
    // list back harder) 315 pt of finger travel past the top. The first
    // move also spends the touch slop, which counts as travel.
    expect(count, 1);
    expect(
      -controller.offset >= RefreshMetrics.triggerDistance ||
          moved >= RefreshMetrics.triggerTravel - 5,
      isTrue,
      reason: 'moved $moved, overscroll ${-controller.offset}',
    );
    expect(moved, lessThan(RefreshMetrics.triggerTravel + 5));
    expect(
      t
          .widget<GlassRefreshIndicator>(find.byType(GlassRefreshIndicator))
          .refreshing,
      isTrue,
    );
    await gesture.up();
    completer.complete();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('the glass path draws the spinner alone: no disk, no scale', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const GlassRefreshIndicator(progress: 0.5, refreshing: false)),
    );
    expect(
      find.descendant(
        of: find.byType(GlassRefreshIndicator),
        matching: find.byType(LiquidGlass),
      ),
      findsNothing,
    );
    expect(
      t.getSize(find.byType(CupertinoActivityIndicator)),
      const Size.square(30),
    );
    // The spokes fade in with the pull.
    final opacity = t.widget<Opacity>(
      find.descendant(
        of: find.byType(GlassRefreshIndicator),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 0.5);
  }, variant: ios);

  testWidgets('RTL: the indicator stays centred', (t) async {
    shaderEnv();
    final completer = Completer<void>();
    await t.pumpWidget(
      plainHost(
        SizedBox(
          width: 300,
          height: 400,
          child: GlassRefresh(onRefresh: () => completer.future, child: _list),
        ),
        direction: TextDirection.rtl,
      ),
    );
    await t.pump();
    await _pullPast(t);
    await t.pump();
    await t.pump(_frame);
    final indicator = find.byType(GlassRefreshIndicator);
    expect(
      t.getCenter(indicator).dx,
      t.getCenter(find.byType(GlassRefresh)).dx,
    );
    completer.complete();
    await t.pumpAndSettle();
  }, variant: ios);

  testWidgets('announces refreshing', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    final first = Completer<void>();
    await t.pumpWidget(
      _host(GlassRefresh(onRefresh: () => first.future, child: _list)),
    );
    await t.pump();
    await _pullPast(t);
    await t.pump();
    await t.pump(_frame);
    expect(find.bySemanticsLabel('Refreshing'), findsOneWidget);
    first.complete();
    await t.pumpAndSettle();

    // A custom label wins over the default.
    final second = Completer<void>();
    await t.pumpWidget(
      _host(
        GlassRefresh(
          onRefresh: () => second.future,
          semanticLabel: 'Loading mail',
          child: _list,
        ),
      ),
    );
    await t.pump();
    await _pullPast(t);
    await t.pump();
    await t.pump(_frame);
    expect(find.bySemanticsLabel('Loading mail'), findsOneWidget);
    second.complete();
    await t.pumpAndSettle();
    s.dispose();
  }, variant: ios);
}
