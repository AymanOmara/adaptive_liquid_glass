import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/chip/chip_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a 32 pt capsule showing the label', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(const GlassChip(label: 'Tag')));
    expect(find.text('Tag'), findsOneWidget);
    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(t.getSize(find.byType(GlassChip)).height, ChipMetrics.height);
  }, variant: ios);

  testWidgets('tapping toggles through onSelected', (t) async {
    shaderEnv();
    final picks = <bool>[];
    await t.pumpWidget(
      plainHost(GlassChip(label: 'Tag', onSelected: picks.add)),
    );
    await t.tap(find.text('Tag'));
    expect(picks, [true]);
    await t.pumpWidget(
      plainHost(GlassChip(label: 'Tag', selected: true, onSelected: picks.add)),
    );
    await t.tap(find.text('Tag'));
    expect(picks, [true, false]);
  }, variant: ios);

  testWidgets('selected tints the glass blue; unselected is untinted', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const Column(
          children: [
            GlassChip(label: 'On', selected: true, glass: Glass.regular),
            GlassChip(label: 'Off', glass: Glass.regular),
          ],
        ),
      ),
    );
    final glasses = t
        .widgetList<LiquidGlass>(find.byType(LiquidGlass))
        .toList();
    expect(glasses[0].glass!.tintColor, const Color(0xFF0088FF));
    expect(glasses[1].glass!.tintColor, isNull);
  }, variant: ios);

  testWidgets('the delete button deletes without toggling', (t) async {
    shaderEnv();
    final picks = <bool>[];
    var deletes = 0;
    await t.pumpWidget(
      plainHost(
        GlassChip(
          label: 'Tag',
          onSelected: picks.add,
          onDeleted: () => deletes++,
        ),
      ),
    );
    await t.tap(find.byIcon(CupertinoIcons.xmark_circle_fill));
    expect(deletes, 1);
    expect(picks, isEmpty);
  }, variant: ios);

  testWidgets("the delete button's label defaults and can be overridden", (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(
        const Column(
          children: [
            GlassChip(label: 'Tag'),
            GlassChip(label: 'Tag'),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Remove Tag'), findsNothing);
    await t.pumpWidget(
      plainHost(
        const Column(
          children: [
            GlassChip(label: 'Tag', onDeleted: _noop),
            GlassChip(label: 'Tag', deleteLabel: 'Clear Tag', onDeleted: _noop),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Remove Tag'), findsOneWidget);
    expect(find.bySemanticsLabel('Clear Tag'), findsOneWidget);
    s.dispose();
  }, variant: ios);

  testWidgets('a selectable chip reports selected for assistive tech', (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(GlassChip(label: 'Tag', selected: true, onSelected: (_) {})),
    );
    expect(
      t.getSemantics(find.text('Tag')),
      isSemantics(isButton: true, isSelected: true),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('right to left: the delete glyph is left of the label', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassChip(label: 'Tag', onDeleted: _noop),
        direction: TextDirection.rtl,
      ),
    );
    expect(
      t.getCenter(find.byIcon(CupertinoIcons.xmark_circle_fill)).dx,
      lessThan(t.getCenter(find.text('Tag')).dx),
    );
  }, variant: ios);

  testWidgets('without onSelected the chip is not a button', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(plainHost(const GlassChip(label: 'Tag')));
    expect(
      t.getSemantics(find.text('Tag')),
      isNot(isSemantics(isButton: true)),
    );
    s.dispose();
  }, variant: ios);

  testWidgets('Material: a FilterChip that toggles', (t) async {
    shaderEnv();
    final picks = <bool>[];
    await t.pumpWidget(appHost(GlassChip(label: 'Tag', onSelected: picks.add)));
    expect(find.byType(FilterChip), findsOneWidget);
    await t.tap(find.text('Tag'));
    await t.pumpAndSettle();
    expect(picks, [true]);
  }, variant: android);

  testWidgets('Material: an InputChip without onSelected', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(const GlassChip(label: 'Tag', onDeleted: _noop)),
    );
    expect(find.byType(InputChip), findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
  }, variant: android);
}

void _noop() {}
