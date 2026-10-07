import 'package:adaptive_liquid_glass/src/activity_indicator/glass_activity_indicator.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/progress/progress_metrics.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

CupertinoActivityIndicator _spinner(WidgetTester t) =>
    t.widget<CupertinoActivityIndicator>(
      find.byType(CupertinoActivityIndicator),
    );

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets("iOS's spinner, 20 x 20 by default", (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const GlassActivityIndicator()));
    await t.pump();
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    expect(
      t.getSize(find.byType(GlassActivityIndicator)),
      const Size(ProgressMetrics.circularSize, ProgressMetrics.circularSize),
    );
    expect(_spinner(t).animating, isTrue);
  }, variant: ios);

  testWidgets('a custom radius sizes it to twice that', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const GlassActivityIndicator(radius: 14)));
    await t.pump();
    expect(t.getSize(find.byType(GlassActivityIndicator)), const Size(28, 28));
  }, variant: ios);

  testWidgets('animating false: a still spinner', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const GlassActivityIndicator(animating: false)),
    );
    await t.pump();
    expect(_spinner(t).animating, isFalse);
  }, variant: ios);

  testWidgets('Reduce Motion: a still spinner', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const GlassActivityIndicator(),
          ),
        ),
      ),
    );
    await t.pump();
    expect(_spinner(t).animating, isFalse);
  }, variant: ios);

  testWidgets('a custom colour reaches the spinner', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const GlassActivityIndicator(color: CupertinoColors.white)),
    );
    await t.pump();
    expect(_spinner(t).color, CupertinoColors.white);
  }, variant: ios);

  testWidgets("'Loading' for assistive tech, or a custom label", (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(const GlassActivityIndicator()));
    await t.pump();
    expect(
      t.getSemantics(find.byType(GlassActivityIndicator)),
      matchesSemantics(label: 'Loading'),
    );
    await t.pumpWidget(
      plainHost(const GlassActivityIndicator(semanticLabel: 'Syncing')),
    );
    await t.pump();
    expect(
      t.getSemantics(find.byType(GlassActivityIndicator)),
      matchesSemantics(label: 'Syncing'),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('Material: a circular progress indicator of the same size', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(const GlassActivityIndicator(radius: 14, color: Colors.red)),
    );
    await t.pump();
    final material = t.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(t.getSize(find.byType(GlassActivityIndicator)), const Size(28, 28));
    expect(material.color, Colors.red);
    expect(material.strokeWidth, ProgressMetrics.ringStroke);
    expect(material.value, isNull);
  }, variant: android);

  testWidgets('Material, animating false: a still indicator', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const GlassActivityIndicator(animating: false)));
    await t.pump();
    expect(
      t
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      0,
    );
  }, variant: android);
}
