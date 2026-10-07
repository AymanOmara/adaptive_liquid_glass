import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/disclosure/disclosure_chevron.dart';
import 'package:adaptive_liquid_glass/src/disclosure/disclosure_metrics.dart';
import 'package:adaptive_liquid_glass/src/list/list_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ExpansionTile;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The group's hairline separators, by colour.
final _separators = find.byWidgetPredicate(
  (w) =>
      w is ColoredBox &&
      w.color.toARGB32() == GlassColors.listSeparator.color.toARGB32(),
);

/// The group's rotating chevron.
final _chevron = find.descendant(
  of: find.byType(GlassDisclosureGroup),
  matching: find.byType(DisclosureChevron),
);

/// The chevron's rotation, whose turns drive it.
Finder get _rotation =>
    find.descendant(of: _chevron, matching: find.byType(RotationTransition));

double _turns(WidgetTester t) =>
    t.widget<RotationTransition>(_rotation).turns.value;

Widget _group({bool? isExpanded, ValueChanged<bool>? onChanged}) =>
    GlassListSection(
      children: [
        GlassDisclosureGroup(
          label: const Text('Advanced'),
          isExpanded: isExpanded,
          onExpansionChanged: onChanged,
          children: const [
            GlassListTile(title: Text('Proxy'), value: 'Off'),
            GlassListTile(title: Text('DNS'), value: 'Automatic'),
          ],
        ),
      ],
    );

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('collapsed by default; taps expand and collapse', (t) async {
    shaderEnv();
    final events = <bool>[];
    await t.pumpWidget(plainHost(_group(onChanged: events.add)));
    await t.pumpAndSettle();
    expect(find.text('Proxy'), findsNothing);
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    expect(find.text('Proxy'), findsOneWidget);
    expect(events, [true]);
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    expect(find.text('Proxy'), findsNothing);
    expect(events, [true, false]);
  }, variant: ios);

  testWidgets('controlled: a tap only reports; a rebuild expands', (t) async {
    shaderEnv();
    final events = <bool>[];
    late StateSetter setOuter;
    var expanded = false;
    await t.pumpWidget(
      plainHost(
        StatefulBuilder(
          builder: (context, setState) {
            setOuter = setState;
            return _group(isExpanded: expanded, onChanged: events.add);
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Proxy'), findsNothing);
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    // The parent still says collapsed, so only the callback fired.
    expect(events, [true]);
    expect(find.text('Proxy'), findsNothing);
    setOuter(() => expanded = true);
    await t.pumpAndSettle();
    expect(find.text('Proxy'), findsOneWidget);
  }, variant: ios);

  testWidgets('the chevron turns a quarter when expanded', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_group()));
    await t.pumpAndSettle();
    expect(_turns(t), 0);
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    expect(_turns(t), DisclosureMetrics.expandedTurns);
  }, variant: ios);

  testWidgets('Reduce Motion: the jump is instant', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _group(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Proxy'), findsNothing);
    await t.tap(find.text('Advanced'));
    await t.pump();
    expect(
      t.widget<SizeTransition>(find.byType(SizeTransition)).sizeFactor.value,
      1,
    );
    expect(find.text('Proxy'), findsOneWidget);
  }, variant: ios);

  testWidgets('right to left: the chevron sits before the label', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_group(), direction: TextDirection.rtl));
    await t.pumpAndSettle();
    expect(
      t.getCenter(_chevron).dx,
      lessThan(t.getCenter(find.text('Advanced')).dx),
    );
    // Expanded it still points down, turning the mirrored way.
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    expect(_turns(t), -DisclosureMetrics.expandedTurns);
  }, variant: ios);

  testWidgets('a button that reports its expanded state', (t) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(plainHost(_group()));
    await t.pumpAndSettle();
    final group = find.text('Advanced');
    expect(
      t.getSemantics(group),
      isSemantics(
        isButton: true,
        isEnabled: true,
        hasExpandedState: true,
        isExpanded: false,
        label: 'Advanced',
      ),
    );
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    expect(
      t.getSemantics(group),
      isSemantics(hasExpandedState: true, isExpanded: true),
    );
    handle.dispose();
  }, variant: ios);

  testWidgets('disabled: taps do nothing', (t) async {
    shaderEnv();
    final events = <bool>[];
    await t.pumpWidget(
      plainHost(
        GlassListSection(
          children: [
            GlassDisclosureGroup(
              label: const Text('Advanced'),
              enabled: false,
              onExpansionChanged: (v) => events.add(v),
              children: const [GlassListTile(title: Text('Proxy'))],
            ),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    expect(events, isEmpty);
    expect(find.text('Proxy'), findsNothing);
  }, variant: ios);

  testWidgets('Material: an ExpansionTile shows the children', (t) async {
    shaderEnv();
    final events = <bool>[];
    await t.pumpWidget(appHost(_group(onChanged: events.add)));
    await t.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsOneWidget);
    expect(find.text('Proxy'), findsNothing);
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    expect(t.getSize(find.text('Proxy')).height, greaterThan(0));
    expect(events, [true]);
  }, variant: android);

  testWidgets('inside a section the group draws its own separators', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassListSection(
          children: [
            GlassDisclosureGroup(
              label: Text('Advanced'),
              children: [
                GlassListTile(title: Text('Proxy')),
                GlassListTile(title: Text('DNS')),
              ],
            ),
            GlassListTile(title: Text('About')),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    // Collapsed the group is one row: only the section's own hairline.
    expect(_separators, findsOneWidget);
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    // The section's, plus the label's and the children's.
    expect(_separators, findsNWidgets(3));
    expect(t.getSize(_separators.first).height, ListMetrics.separatorThickness);
  }, variant: ios);

  testWidgets('children indent; hairlines follow the last visible row', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        const GlassListSection(
          children: [
            GlassDisclosureGroup(
              label: Text('Advanced'),
              children: [
                GlassListTile(title: Text('Proxy')),
                GlassListTile(title: Text('DNS')),
              ],
            ),
            GlassListTile(title: Text('About')),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    // Collapsed, the group's own hairline starts under the label.
    expect(
      t.getTopLeft(_separators).dx,
      t.getTopLeft(find.text('Advanced')).dx,
    );
    await t.tap(find.text('Advanced'));
    await t.pumpAndSettle();
    final child = t.getTopLeft(find.text('Proxy')).dx;
    expect(
      child - t.getTopLeft(find.text('Advanced')).dx,
      DisclosureMetrics.childIndent,
    );
    // Expanded, the hairlines below both children (the last one drawn
    // for the section) start at the indented titles.
    final starts = [
      for (final e in _separators.evaluate())
        t.getTopLeft(find.byWidget(e.widget)).dx,
    ];
    expect(starts.where((x) => x == child), hasLength(2));
  }, variant: ios);

  testWidgets('the chevron is the label colour', (t) async {
    shaderEnv();
    await t.pumpWidget(plainHost(_group()));
    expect(
      t.widget<DisclosureChevron>(_chevron).color.toARGB32(),
      CupertinoColors.label.color.toARGB32(),
    );
  }, variant: ios);
}
