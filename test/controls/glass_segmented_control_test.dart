import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/controls/glass_thumb.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _segments = [
  GlassSegment(value: 'd', label: Text('Day')),
  GlassSegment(value: 'w', label: Text('Week')),
  GlassSegment(value: 'm', label: Text('Month')),
];

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  String value = 'd';
  final picks = <String>[];

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 300,
    child: GlassSegmentedControl<String>(
      segments: _segments,
      selected: value,
      onChanged: (v) => setState(() {
        picks.add(v);
        value = v;
      }),
    ),
  );
}

_HarnessState _state(WidgetTester t) =>
    t.state<_HarnessState>(find.byType(_Harness));

Finder get _lens =>
    find.byWidgetPredicate((w) => w is LiquidGlass && w.glass == Glass.clear);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('tapping a segment selects it and moves the thumb', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    await t.tap(find.text('Month'));
    await t.pumpAndSettle();
    expect(_state(t).picks, ['m']);
    expect(
      t.getCenter(find.byType(GlassThumb)).dx,
      moreOrLessEquals(t.getCenter(find.text('Month')).dx, epsilon: 1),
    );
  }, variant: ios);

  testWidgets('dragging the lens picks on release only', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const _Harness()));
    final g = await t.startGesture(t.getCenter(find.text('Day')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(_lens, findsOneWidget);
    await g.moveTo(t.getCenter(find.text('Week')));
    await t.pump();
    expect(_state(t).picks, isEmpty);
    await g.up();
    await t.pumpAndSettle();
    expect(_state(t).picks, ['w']);
    expect(_lens, findsNothing);
  }, variant: ios);

  testWidgets('right to left: the first segment is on the right', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const _Harness(), direction: TextDirection.rtl),
    );
    expect(
      t.getCenter(find.byType(GlassThumb)).dx,
      moreOrLessEquals(t.getCenter(find.text('Day')).dx, epsilon: 1),
    );
    expect(
      t.getCenter(find.text('Day')).dx,
      greaterThan(t.getCenter(find.text('Month')).dx),
    );
  }, variant: ios);

  testWidgets('segments are selectable buttons for assistive tech', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(const _Harness()));
    expect(
      t.getSemantics(find.text('Day')),
      matchesSemantics(
        label: 'Day',
        isButton: true,
        isInMutuallyExclusiveGroup: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('Material: a Material 3 segmented button', (t) async {
    shaderEnv();
    await t.pumpWidget(appHost(const _Harness()));
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    await t.tap(find.text('Week'));
    await t.pumpAndSettle();
    expect(_state(t).picks, ['w']);
  }, variant: android);
}
