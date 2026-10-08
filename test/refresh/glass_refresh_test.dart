import 'dart:async';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
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

/// The scale-in of the indicator's disk: the `Transform` between the
/// indicator and its `LiquidGlass`.
Finder get _diskScale => find
    .ancestor(of: find.byType(LiquidGlass), matching: find.byType(Transform))
    .first;

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
    await t.drag(find.text('Row 0'), const Offset(0, 150));
    await t.pump();
    await t.pump(_frame);
    expect(count, 1);
    // While the refresh is pending a second pull does not call again.
    await t.drag(find.text('Row 0'), const Offset(0, 150));
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
    await t.drag(find.text('Row 0'), const Offset(0, 150));
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
    expect(done.progress, moreOrLessEquals(0, epsilon: 0.01));
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

  testWidgets('Reduce Motion: no scale-in', (t) async {
    shaderEnv();
    Widget host(bool reduceMotion) => plainHost(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: SizedBox(
            width: 300,
            height: 400,
            child: GlassRefresh(onRefresh: () async {}, child: _list),
          ),
        ),
      ),
    );

    double diskScale() => t.widget<Transform>(_diskScale).transform.entry(0, 0);

    // Mid-pull the disk scales in from its minimum...
    await t.pumpWidget(host(false));
    await t.pump();
    var gesture = await t.startGesture(t.getCenter(find.text('Row 0')));
    await gesture.moveBy(const Offset(0, 30));
    await t.pump();
    expect(diskScale(), lessThan(1));
    await gesture.up();
    await t.pumpAndSettle();

    // ...and with Reduce Motion it stays at full size.
    await t.pumpWidget(host(true));
    await t.pump();
    gesture = await t.startGesture(t.getCenter(find.text('Row 0')));
    await gesture.moveBy(const Offset(0, 30));
    await t.pump();
    expect(diskScale(), moreOrLessEquals(1));
    await gesture.up();
    await t.pumpAndSettle();
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
    await t.drag(find.text('Row 0'), const Offset(0, 150));
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
    await t.drag(find.text('Row 0'), const Offset(0, 150));
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
    await t.drag(find.text('Row 0'), const Offset(0, 150));
    await t.pump();
    await t.pump(_frame);
    expect(find.bySemanticsLabel('Loading mail'), findsOneWidget);
    second.complete();
    await t.pumpAndSettle();
    s.dispose();
  }, variant: ios);
}
