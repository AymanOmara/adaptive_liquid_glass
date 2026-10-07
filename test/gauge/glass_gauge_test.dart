import 'package:adaptive_liquid_glass/src/core/glass_system_colors.dart';
import 'package:adaptive_liquid_glass/src/gauge/gauge_arc_painter.dart';
import 'package:adaptive_liquid_glass/src/gauge/gauge_linear_painter.dart';
import 'package:adaptive_liquid_glass/src/gauge/gauge_metrics.dart';
import 'package:adaptive_liquid_glass/src/gauge/gauge_ring_painter.dart';
import 'package:adaptive_liquid_glass/src/gauge/glass_gauge.dart';
import 'package:adaptive_liquid_glass/src/gauge/glass_gauge_style.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show CircularProgressIndicator, LinearProgressIndicator;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

CustomPaint _paint(WidgetTester t) => t.widget(
  find.descendant(
    of: find.byType(GlassGauge),
    matching: find.byType(CustomPaint),
  ),
);

Finder get _track => find.descendant(
  of: find.byType(GlassGauge),
  matching: find.byType(CustomPaint),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('linear: the painter fills to the fraction of the range', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const GlassGauge(value: 21, min: 0, max: 40)));
    final painter = _paint(t).painter;
    expect(painter, isA<GaugeLinearPainter>());
    expect((painter as GaugeLinearPainter).fraction, moreOrLessEquals(21 / 40));
    // Outside the range clamps into it.
    await t.pumpWidget(plainHost(const GlassGauge(value: 2, max: 1)));
    expect(
      (_paint(t).painter as GaugeLinearPainter).fraction,
      moreOrLessEquals(1),
    );
    await t.pumpWidget(plainHost(const GlassGauge(value: -1)));
    expect(
      (_paint(t).painter as GaugeLinearPainter).fraction,
      moreOrLessEquals(0),
    );
  }, variant: ios);

  testWidgets('linear layout: label above, min at start, max at end', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassGauge(
          value: 0.62,
          label: Text('Battery'),
          currentValueLabel: Text('62%'),
          minimumValueLabel: Text('0'),
          maximumValueLabel: Text('100'),
        ),
      ),
    );
    final track = t.getRect(_track);
    expect(
      t.getRect(find.text('Battery')).bottom,
      lessThanOrEqualTo(track.top),
    );
    expect(t.getCenter(find.text('0')).dx, lessThan(track.center.dx));
    expect(t.getCenter(find.text('100')).dx, greaterThan(track.center.dx));
    // The label and the current value centre over and under the gauge.
    expect(t.getRect(find.text('62%')).top, greaterThan(track.bottom));
    final centre = t.getCenter(find.byType(GlassGauge)).dx;
    expect(t.getCenter(find.text('62%')).dx, closeTo(centre, 0.1));
    expect(t.getCenter(find.text('Battery')).dx, closeTo(centre, 0.1));
    expect(track.height, GaugeMetrics.linearTrackHeight);
  }, variant: ios);

  testWidgets('right to left: min right of max, fill from the right', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassGauge(
          value: 0.62,
          minimumValueLabel: Text('0'),
          maximumValueLabel: Text('100'),
        ),
        direction: TextDirection.rtl,
      ),
    );
    expect(
      t.getCenter(find.text('0')).dx,
      greaterThan(t.getCenter(find.text('100')).dx),
    );
    expect((_paint(t).painter as GaugeLinearPainter).rtl, isTrue);
  }, variant: ios);

  testWidgets('accessoryCircular: a square with the value centred', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassGauge(
          value: 0.4,
          style: GlassGaugeStyle.accessoryCircular,
          currentValueLabel: Text('40%'),
        ),
      ),
    );
    expect(
      t.getSize(find.byType(GlassGauge)),
      const Size.square(GaugeMetrics.circularDiameter),
    );
    // The value sits a little above the ring's centre.
    expect(
      t.getCenter(find.text('40%')),
      t.getCenter(find.byType(GlassGauge)) -
          const Offset(0, GaugeMetrics.circularValueLift),
    );
    final painter = _paint(t).painter;
    expect(painter, isA<GaugeArcPainter>());
    expect((painter as GaugeArcPainter).fraction, moreOrLessEquals(0.4));
    // The ring paints across the whole square, not a zero-size box.
    expect(t.getSize(_track), const Size.square(GaugeMetrics.circularDiameter));
  }, variant: ios);

  testWidgets('capacity: the ring fills to the fraction; RTL flips it', (
    t,
  ) async {
    shaderEnv();
    Widget capacity({TextDirection direction = TextDirection.ltr}) => plainHost(
      const GlassGauge(
        value: 21,
        min: 0,
        max: 40,
        style: GlassGaugeStyle.accessoryCircularCapacity,
      ),
      direction: direction,
    );
    await t.pumpWidget(capacity());
    final painter = _paint(t).painter;
    expect(painter, isA<GaugeRingPainter>());
    expect((painter as GaugeRingPainter).fraction, moreOrLessEquals(21 / 40));
    expect(painter.rtl, isFalse);
    await t.pumpWidget(capacity(direction: TextDirection.rtl));
    expect((_paint(t).painter as GaugeRingPainter).rtl, isTrue);
  }, variant: ios);

  testWidgets('the label and the percentage for assistive tech', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(
        const GlassGauge(
          value: 0.62,
          label: Text('Battery'),
          semanticLabel: 'Battery level',
        ),
      ),
    );
    expect(
      t.getSemantics(find.byType(GlassGauge)),
      matchesSemantics(label: 'Battery level', value: '62%', isReadOnly: true),
    );
    await t.pumpWidget(
      plainHost(const GlassGauge(value: 0.62, label: Text('Battery'))),
    );
    expect(
      t.getSemantics(find.byType(GlassGauge)),
      matchesSemantics(label: 'Battery', value: '62%', isReadOnly: true),
    );
    handle.dispose();
  }, variant: ios);

  testWidgets('the tint defaults to SwiftUI\'s; explicit wins', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const GlassGauge(value: 0.5)));
    expect(
      (_paint(t).painter as GaugeLinearPainter).color.toARGB32(),
      GlassSystemColors.blue.color.toARGB32(),
    );
    await t.pumpWidget(
      plainHost(
        const GlassGauge(
          value: 0.5,
          style: GlassGaugeStyle.accessoryCircularCapacity,
        ),
      ),
    );
    final ring = _paint(t).painter as GaugeRingPainter;
    expect(ring.color.toARGB32(), CupertinoColors.label.color.toARGB32());
    // The capacity track is the tint dimmed.
    expect(ring.track.a, moreOrLessEquals(GaugeMetrics.circularTrackOpacity));
    await t.pumpWidget(
      plainHost(
        const GlassGauge(value: 0.5, tint: CupertinoColors.systemOrange),
      ),
    );
    expect(
      (_paint(t).painter as GaugeLinearPainter).color.toARGB32(),
      CupertinoColors.systemOrange.color.toARGB32(),
    );
  }, variant: ios);

  testWidgets('the accessory ring and its dot are the tint', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassGauge(
          value: 0.4,
          style: GlassGaugeStyle.accessoryCircular,
          tint: CupertinoColors.systemOrange,
        ),
      ),
    );
    final arc = _paint(t).painter as GaugeArcPainter;
    expect(arc.color.toARGB32(), CupertinoColors.systemOrange.color.toARGB32());
  }, variant: ios);

  testWidgets('Reduce Motion: renders identically, no exceptions', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: const GlassGauge(value: 0.5),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
      (_paint(t).painter as GaugeLinearPainter).fraction,
      moreOrLessEquals(0.5),
    );
  }, variant: ios);

  testWidgets('Material: progress indicators with the fraction', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        const GlassGauge(
          value: 21,
          min: 0,
          max: 40,
          label: Text('Temperature'),
          currentValueLabel: Text('21°'),
          minimumValueLabel: Text('0'),
          maximumValueLabel: Text('40'),
        ),
      ),
    );
    final bar = t.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, moreOrLessEquals(21 / 40));
    for (final style in [
      GlassGaugeStyle.accessoryCircular,
      GlassGaugeStyle.accessoryCircularCapacity,
    ]) {
      await t.pumpWidget(
        appHost(
          GlassGauge(
            value: 21,
            min: 0,
            max: 40,
            style: style,
            currentValueLabel: const Text('21°'),
          ),
        ),
      );
      final ring = t.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(ring.value, moreOrLessEquals(21 / 40));
      expect(
        ring.backgroundColor!.a,
        moreOrLessEquals(GaugeMetrics.circularTrackOpacity),
      );
    }
  }, variant: android);

  test('min must be less than max', () {
    expect(() => GlassGauge(value: 0, min: 1, max: 1), throwsAssertionError);
    expect(() => GlassGauge(value: 0, min: 2, max: 1), throwsAssertionError);
  });
}
