import 'package:adaptive_liquid_glass/src/badge/badge_metrics.dart';
import 'package:adaptive_liquid_glass/src/badge/glass_badge.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a red capsule, 18 high, with its label', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const GlassBadge(label: '3')));
    expect(find.text('3'), findsOneWidget);
    expect(t.getSize(find.byType(ConstrainedBox)).height, BadgeMetrics.height);
    final shape =
        t.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration
            as ShapeDecoration;
    final c = shape.color!;
    expect(c is CupertinoDynamicColor ? c.color : c, const Color(0xFFFF383C));
  }, variant: ios);

  testWidgets('a dot when the label is null or empty', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const GlassBadge(label: '')));
    final dot = find.byType(DecoratedBox);
    expect(t.getSize(dot), const Size(BadgeMetrics.dot, BadgeMetrics.dot));
    expect(find.byType(Text), findsNothing);
  }, variant: ios);

  testWidgets('count caps at the max; 0 hides the badge', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(GlassBadge.count(count: 120)));
    expect(find.text('99+'), findsOneWidget);
    const child = SizedBox(width: 24, height: 24);
    await t.pumpWidget(plainHost(GlassBadge.count(count: 0, child: child)));
    expect(find.byType(DecoratedBox), findsNothing);
    expect(t.getSize(find.byType(SizedBox)), const Size(24, 24));
  }, variant: ios);

  testWidgets('the badge overhangs the child\'s top trailing corner', (
    t,
  ) async {
    shaderEnv();
    const child = SizedBox(width: 24, height: 24);
    await t.pumpWidget(plainHost(const GlassBadge(label: '3', child: child)));
    final badge = t.getRect(find.byType(ConstrainedBox));
    final icon = t.getRect(find.byType(SizedBox));
    expect(badge.top, lessThan(icon.top));
    expect(badge.right, greaterThan(icon.right));

    await t.pumpWidget(
      plainHost(
        const GlassBadge(label: '3', child: child),
        direction: TextDirection.rtl,
      ),
    );
    final rtlBadge = t.getRect(find.byType(ConstrainedBox));
    final rtlIcon = t.getRect(find.byType(SizedBox));
    expect(rtlBadge.top, lessThan(rtlIcon.top));
    expect(rtlBadge.left, lessThan(rtlIcon.left));
  }, variant: ios);

  testWidgets('the badge is labelled for assistive tech', (t) async {
    shaderEnv();
    final semantics = t.ensureSemantics();
    await t.pumpWidget(plainHost(GlassBadge.count(count: 3)));
    expect(find.semantics.byLabel('3'), findsOneWidget);
    await t.pumpWidget(
      plainHost(const GlassBadge(label: '3', semanticLabel: '3 unread')),
    );
    expect(find.semantics.byLabel('3 unread'), findsOneWidget);
    semantics.dispose();
  }, variant: ios);

  testWidgets('isVisible false shows only the child', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassBadge(
          label: '3',
          isVisible: false,
          child: SizedBox(width: 24, height: 24),
        ),
      ),
    );
    expect(find.byType(DecoratedBox), findsNothing);
    expect(find.text('3'), findsNothing);
    expect(t.getSize(find.byType(SizedBox)), const Size(24, 24));
  }, variant: ios);

  testWidgets('Material: a Material 3 Badge', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        GlassBadge.count(count: 3, child: const Icon(CupertinoIcons.mail)),
      ),
    );
    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  }, variant: android);
}
