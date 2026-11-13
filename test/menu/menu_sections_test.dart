import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/menu/glass_menu_row.dart';
import 'package:adaptive_liquid_glass/src/menu/menu_metrics.dart';
import 'package:adaptive_liquid_glass/src/menu/menu_sections.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

List<GlassMenuItem> _items(List<String> picks) => [
  GlassMenuItem(label: 'Paste', onSelected: () => picks.add('paste')),
  GlassMenuItem.section(
    title: 'Sort By',
    items: [
      GlassMenuItem(label: 'Name', onSelected: () => picks.add('name')),
      GlassMenuItem(label: 'Date', onSelected: () => picks.add('date')),
    ],
  ),
  GlassMenuItem.submenu(
    label: 'Share',
    icon: CupertinoIcons.share,
    items: [
      GlassMenuItem(label: 'Mail', onSelected: () => picks.add('mail')),
      GlassMenuItem(label: 'Messages', onSelected: () => picks.add('msg')),
    ],
  ),
];

Widget _app(
  List<String> picks, {
  VoidCallback? primaryAction,
  GlassMenuController? controller,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GlassMenuButton(
          items: _items(picks),
          primaryAction: primaryAction,
          controller: controller,
        ),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester t) async {
  await t.tap(find.bySemanticsLabel('More'));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  test('loose rows between sections form their own sections', () {
    final sections = menuSections(_items([]));
    expect(sections.map((s) => s.title), [null, 'Sort By', null]);
    expect(sections.map((s) => s.rows.map((r) => r.label)), [
      ['Paste'],
      ['Name', 'Date'],
      ['Share'],
    ]);
    expect(menuActions(_items([])).map((r) => r.label), [
      'Paste',
      'Name',
      'Date',
      'Mail',
      'Messages',
    ]);
  });

  test('a section is never enabled; a submenu is when it has rows', () {
    expect(const GlassMenuItem.section(items: []).enabled, isFalse);
    expect(const GlassMenuItem.submenu(label: 'S', items: []).enabled, isFalse);
    expect(
      GlassMenuItem.submenu(
        label: 'S',
        items: [GlassMenuItem(label: 'A', onSelected: () {})],
      ).enabled,
      isTrue,
    );
  });

  testWidgets('sections show a title and dividers between them', (t) async {
    shaderEnv();
    await t.pumpWidget(_app([]));
    await _open(t);
    expect(find.text('Sort By'), findsOneWidget);
    // A divider between each of the three sections.
    final dividers = find.byWidgetPredicate(
      (w) =>
          w is SizedBox &&
          w.height == MenuMetrics.dividerThickness &&
          w.child is ColoredBox,
    );
    expect(dividers, findsNWidgets(2));
    final paste = t.getRect(find.text('Paste'));
    final name = t.getRect(find.text('Name'));
    // Rows, a divider and the title between Paste and Name.
    expect(
      name.top - paste.top,
      greaterThan(MenuMetrics.rowHeight + MenuMetrics.headerHeight),
    );
    expect(
      t.getSemantics(find.text('Sort By')).flagsCollection.isHeader,
      isTrue,
    );
  }, variant: ios);

  testWidgets('a submenu row has a chevron and opens its card', (t) async {
    shaderEnv();
    final picks = <String>[];
    await t.pumpWidget(_app(picks));
    await _open(t);
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsOneWidget);
    await t.tap(find.text('Share'));
    await t.pumpAndSettle();
    // The card over the receded menu: its own row with a chevron down.
    expect(find.byIcon(CupertinoIcons.chevron_down), findsOneWidget);
    expect(find.text('Mail'), findsOneWidget);
    expect(find.text('Share'), findsNWidgets(2));
    await t.tap(find.text('Mail'));
    await t.pumpAndSettle();
    expect(picks, ['mail']);
    expect(find.text('Mail'), findsNothing);
  }, variant: ios);

  testWidgets('the submenu row of the card goes back to the menu', (t) async {
    shaderEnv();
    final picks = <String>[];
    await t.pumpWidget(_app(picks));
    await _open(t);
    await t.tap(find.text('Share'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(CupertinoIcons.chevron_down));
    await t.pumpAndSettle();
    expect(find.text('Mail'), findsNothing);
    expect(find.text('Paste'), findsOneWidget);
    await t.tap(find.text('Paste'));
    await t.pumpAndSettle();
    expect(picks, ['paste']);
  }, variant: ios);

  testWidgets('a glide skips titles and dividers and opens a submenu', (
    t,
  ) async {
    shaderEnv();
    final picks = <String>[];
    final controller = GlassMenuController();
    await t.pumpWidget(_app(picks, controller: controller));
    controller.open();
    await t.pumpAndSettle();
    final title = t.getCenter(find.text('Sort By'));
    // Over the menu, but a title highlights nothing.
    expect(controller.glideTo(title), isTrue);
    await t.pump();
    expect(
      t
          .widgetList<GlassMenuRow>(find.byType(GlassMenuRow))
          .where((r) => r.highlighted),
      isEmpty,
    );
    expect(controller.glideTo(t.getCenter(find.text('Date'))), isTrue);
    await t.pump();
    expect(
      t
          .widget<GlassMenuRow>(
            find.ancestor(
              of: find.text('Date'),
              matching: find.byType(GlassMenuRow),
            ),
          )
          .highlighted,
      isTrue,
    );
    expect(controller.glideTo(t.getCenter(find.text('Share'))), isTrue);
    controller.endGlide();
    await t.pumpAndSettle();
    expect(find.text('Mail'), findsOneWidget);
    expect(picks, isEmpty);
  }, variant: ios);

  testWidgets('primaryAction: a tap runs it, a long-press opens the menu', (
    t,
  ) async {
    shaderEnv();
    final picks = <String>[];
    await t.pumpWidget(_app(picks, primaryAction: () => picks.add('primary')));
    await t.tap(find.bySemanticsLabel('More'));
    await t.pumpAndSettle();
    expect(picks, ['primary']);
    expect(find.text('Paste'), findsNothing);
    await t.longPress(find.bySemanticsLabel('More'));
    await t.pumpAndSettle();
    expect(find.text('Paste'), findsOneWidget);
    expect(picks, ['primary']);
  }, variant: ios);

  testWidgets('Material: sections, a title and a submenu', (t) async {
    shaderEnv();
    final picks = <String>[];
    await t.pumpWidget(_app(picks));
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(find.text('Sort By'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
    expect(find.byType(SubmenuButton), findsOneWidget);
    await t.tap(find.text('Share'));
    await t.pumpAndSettle();
    await t.tap(find.text('Mail'));
    await t.pumpAndSettle();
    expect(picks, ['mail']);
  }, variant: android);

  testWidgets('Material: primaryAction runs on tap, long-press opens', (
    t,
  ) async {
    shaderEnv();
    final picks = <String>[];
    await t.pumpWidget(_app(picks, primaryAction: () => picks.add('primary')));
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(picks, ['primary']);
    expect(find.text('Paste'), findsNothing);
    await t.longPress(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(find.text('Paste'), findsOneWidget);
  }, variant: android);

  group('GlassContextMenu', () {
    Widget app(List<String> picks) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: GlassContextMenu(
            items: _items(picks),
            child: const SizedBox(
              width: 200,
              height: 120,
              child: ColoredBox(color: Colors.white, child: Text('Card')),
            ),
          ),
        ),
      ),
    );

    testWidgets('sections and a submenu', (t) async {
      shaderEnv();
      final picks = <String>[];
      await t.pumpWidget(app(picks));
      await t.longPress(find.text('Card'));
      await t.pumpAndSettle();
      expect(find.text('Sort By'), findsOneWidget);
      await t.tap(find.text('Share'));
      await t.pumpAndSettle();
      await t.tap(find.text('Messages'));
      await t.pumpAndSettle();
      expect(picks, ['msg']);
    }, variant: ios);

    testWidgets('assistive tech gets every action, submenus opened up', (
      t,
    ) async {
      shaderEnv();
      final handle = t.ensureSemantics();
      await t.pumpWidget(app([]));
      final actions = t
          .getSemantics(find.text('Card'))
          .getSemanticsData()
          .customSemanticsActionIds;
      expect(actions, hasLength(5));
      handle.dispose();
    }, variant: ios);

    testWidgets('Material: titles and dividers in the popup', (t) async {
      shaderEnv();
      final picks = <String>[];
      await t.pumpWidget(app(picks));
      await t.longPress(find.text('Card'));
      await t.pumpAndSettle();
      expect(find.text('Sort By'), findsOneWidget);
      expect(find.byType(PopupMenuDivider), findsNWidgets(2));
      await t.tap(find.text('Mail'));
      await t.pumpAndSettle();
      expect(picks, ['mail']);
    }, variant: android);
  });
}
