import 'dart:async';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _host(Future<void> Function() onRefresh, {String? semanticLabel}) =>
    plainHost(
      SizedBox(
        width: 300,
        height: 400,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverGlassRefresh(
              onRefresh: onRefresh,
              semanticLabel: semanticLabel,
            ),
            SliverList(
              delegate: SliverChildListDelegate(
                List.generate(
                  30,
                  (i) => SizedBox(height: 40, child: Text('Row $i')),
                ),
              ),
            ),
          ],
        ),
      ),
    );

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('pull past the threshold calls onRefresh once', (t) async {
    shaderEnv();
    var count = 0;
    final completer = Completer<void>();
    await t.pumpWidget(
      _host(() {
        count++;
        return completer.future;
      }),
    );
    await t.pump();
    await t.drag(find.text('Row 0'), const Offset(0, 150));
    await t.pump();
    expect(count, 1);
    // While the refresh is pending a second pull does not call again.
    await t.drag(find.text('Row 0'), const Offset(0, 150));
    await t.pump();
    expect(count, 1);
    completer.complete();
    await t.pumpAndSettle();
    expect(count, 1);
  }, variant: ios);

  testWidgets('a short pull does not refresh', (t) async {
    shaderEnv();
    var count = 0;
    await t.pumpWidget(
      _host(() {
        count++;
        return Future<void>.value();
      }),
    );
    await t.pump();
    await t.drag(find.text('Row 0'), const Offset(0, 30));
    await t.pump();
    expect(count, 0);
    await t.pumpAndSettle();
    expect(count, 0);
  }, variant: ios);

  testWidgets('the indicator shows while pending and goes after', (t) async {
    shaderEnv();
    final completer = Completer<void>();
    await t.pumpWidget(_host(() => completer.future));
    await t.pump();
    // Idle: the control builds no child at all.
    expect(find.byType(GlassRefreshIndicator), findsNothing);
    await t.drag(find.text('Row 0'), const Offset(0, 150));
    await t.pump();
    expect(
      t
          .widget<GlassRefreshIndicator>(find.byType(GlassRefreshIndicator))
          .refreshing,
      isTrue,
    );
    completer.complete();
    await t.pumpAndSettle();
    expect(find.byType(GlassRefreshIndicator), findsNothing);
  }, variant: ios);

  testWidgets('announces refreshing', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    final first = Completer<void>();
    await t.pumpWidget(_host(() => first.future));
    await t.pump();
    await t.drag(find.text('Row 0'), const Offset(0, 150));
    await t.pump();
    expect(find.bySemanticsLabel('Refreshing'), findsOneWidget);
    first.complete();
    await t.pumpAndSettle();

    // A custom label wins over the default.
    final second = Completer<void>();
    await t.pumpWidget(
      _host(() => second.future, semanticLabel: 'Loading mail'),
    );
    await t.pump();
    await t.drag(find.text('Row 0'), const Offset(0, 150));
    await t.pump();
    expect(find.bySemanticsLabel('Loading mail'), findsOneWidget);
    second.complete();
    await t.pumpAndSettle();
    s.dispose();
  }, variant: ios);
}
