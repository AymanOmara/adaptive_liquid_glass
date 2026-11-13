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

  testWidgets('a subtitle follows the label, secondary, inside 32 pt', (
    t,
  ) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      plainHost(GlassChip(label: 'Tag', subtitle: '3', onSelected: (_) {})),
    );
    expect(t.getSize(find.byType(GlassChip)).height, ChipMetrics.height);
    expect(
      t.getCenter(find.text('3')).dx,
      greaterThan(t.getCenter(find.text('Tag')).dx),
    );
    final label = t.widget<Text>(find.text('Tag')).style!;
    final sub = t.widget<Text>(find.text('3')).style!;
    expect(sub.color, isNot(label.color));
    expect(find.bySemanticsLabel(RegExp(r'Tag.*3', dotAll: true)), findsOne);
    s.dispose();
  }, variant: ios);

  testWidgets('Material: a subtitle follows the label inside 32 pt', (t) async {
    shaderEnv();
    final s = t.ensureSemantics();
    await t.pumpWidget(
      appHost(GlassChip(label: 'Tag', subtitle: '3', onSelected: (_) {})),
    );
    expect(t.getSize(find.byType(GlassChip)).height, ChipMetrics.height);
    expect(
      t.getCenter(find.text('3')).dx,
      greaterThan(t.getCenter(find.text('Tag')).dx),
    );
    expect(find.bySemanticsLabel(RegExp(r'Tag.*3', dotAll: true)), findsOne);
    s.dispose();
  }, variant: android);

  testWidgets('Material: as tall as the glass chip', (t) async {
    shaderEnv();
    await t.pumpWidget(
      appHost(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassChip(label: 'Tag', onSelected: (_) {}),
            GlassChip(label: 'Tag', onDeleted: () {}),
          ],
        ),
      ),
    );
    for (final chip in t.widgetList(find.byType(GlassChip))) {
      expect(t.getSize(find.byWidget(chip)).height, ChipMetrics.height);
    }
  }, variant: android);

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

void _noop() {
  group('W25 trailing', () {
    testWidgets('glass: after the label and subtitle, before delete; the '
        'capsule stays 32 pt', (t) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          GlassChip(
            label: 'Labels',
            subtitle: '3',
            trailing: const Icon(CupertinoIcons.chevron_down, key: Key('t')),
            onDeleted: () {},
          ),
        ),
      );
      final label = t.getRect(find.text('Labels'));
      final subtitle = t.getRect(find.text('3'));
      final trailing = t.getRect(find.byKey(const Key('t')));
      final delete = t.getRect(find.byIcon(CupertinoIcons.xmark_circle_fill));
      expect(label.right, lessThanOrEqualTo(subtitle.left));
      expect(subtitle.right + ChipMetrics.iconGap, trailing.left);
      expect(trailing.right, lessThanOrEqualTo(delete.left));
      expect(trailing.width, ChipMetrics.iconSize);
      expect(t.getSize(find.byType(GlassChip)).height, ChipMetrics.height);
    }, variant: ios);

    testWidgets('glass: white on a selected chip', (t) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          const GlassChip(
            label: 'Tag',
            selected: true,
            trailing: Icon(CupertinoIcons.chevron_down, key: Key('t')),
          ),
        ),
      );
      final theme = IconTheme.of(t.element(find.byKey(const Key('t'))));
      expect(theme.color, const Color(0xFFFFFFFF));
    }, variant: ios);

    testWidgets('glass: right to left puts it before the label', (t) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: GlassChip(
              label: 'Tag',
              trailing: Icon(CupertinoIcons.chevron_down, key: Key('t')),
            ),
          ),
        ),
      );
      expect(
        t.getRect(find.byKey(const Key('t'))).right,
        lessThanOrEqualTo(t.getRect(find.text('Tag')).left),
      );
    }, variant: ios);

    testWidgets('Material: ends the chip label', (t) async {
      await t.pumpWidget(
        plainHost(
          GlassChip(
            label: 'Tag',
            onSelected: (_) {},
            trailing: const Icon(Icons.expand_more, key: Key('t')),
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(FilterChip),
          matching: find.byKey(const Key('t')),
        ),
        findsOneWidget,
      );
      expect(
        t.getRect(find.byKey(const Key('t'))).left,
        greaterThan(t.getRect(find.text('Tag')).right),
      );
    }, variant: android);
  });
}
