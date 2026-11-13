import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/disclosure/disclosure_chevron.dart';
import 'package:adaptive_liquid_glass/src/list/list_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

List<GlassSidebarSection<String>> _sections({
  bool? tags,
  ValueChanged<bool>? onTags,
}) => [
  const GlassSidebarSection(
    header: Text('Library'),
    items: [
      GlassSidebarItem(
        value: 'Inbox',
        title: Text('Inbox'),
        icon: Icon(CupertinoIcons.tray),
      ),
      GlassSidebarItem(
        value: 'Drafts',
        title: Text('Drafts'),
        icon: Icon(CupertinoIcons.doc),
        badge: '3',
      ),
      GlassSidebarItem(
        value: 'Sent',
        title: Text('Sent'),
        icon: Icon(CupertinoIcons.paperplane),
      ),
    ],
  ),
  GlassSidebarSection(
    header: const Text('Tags'),
    isExpanded: tags,
    onExpansionChanged: onTags,
    items: const [
      GlassSidebarItem(value: 'Work', title: Text('Work')),
      GlassSidebarItem(value: 'Family', title: Text('Family')),
    ],
  ),
];

Widget _host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(402, 874),
      padding: const EdgeInsets.only(top: 62, bottom: 34),
      platformBrightness: brightness,
      disableAnimations: reduceMotion,
    ),
    child: CupertinoTheme(
      data: CupertinoThemeData(brightness: brightness),
      child: Directionality(textDirection: direction, child: child),
    ),
  ),
);

void _size(WidgetTester t, Size s) {
  t.view.physicalSize = s;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('compact: first platter 42.33 under the safe top, rows 54, '
      'header 17 semibold secondary label', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(
        GlassSidebarList<String>(sections: _sections(), selection: 'Inbox'),
      ),
    );
    final inbox = t.getRect(
      find.ancestor(
        of: find.text('Inbox'),
        matching: find.byType(GlassListTile),
      ),
    );
    expect(inbox.top, closeTo(62 + 42.33, 0.01));
    expect(inbox.height, closeTo(ListMetrics.minRowHeight, 0.01));
    expect(inbox.left, ListMetrics.margin);
    final style = t.widget<RichText>(
      find.descendant(
        of: find.text('Library'),
        matching: find.byType(RichText),
      ),
    );
    expect(style.text.style?.fontWeight, FontWeight.w600);
    expect(style.text.style?.fontSize, 17);
    expect(
      style.text.style?.color,
      CupertinoDynamicColor.resolve(
        GlassColors.secondaryLabel,
        t.element(find.text('Library')),
      ),
    );
  }, variant: ios);

  testWidgets('tapping a row reports its value', (t) async {
    shaderEnv();
    String? picked;
    await t.pumpWidget(
      _host(
        GlassSidebarList<String>(
          sections: _sections(),
          selection: 'Inbox',
          onSelectionChanged: (v) => picked = v,
        ),
      ),
    );
    await t.tap(find.text('Drafts'));
    await t.pumpAndSettle();
    expect(picked, 'Drafts');
    expect(find.text('3'), findsOneWidget);
  }, variant: ios);

  testWidgets('a header tap collapses its rows; semantics report expanded', (
    t,
  ) async {
    shaderEnv();
    final handle = t.ensureSemantics();
    await t.pumpWidget(
      _host(
        GlassSidebarList<String>(sections: _sections(), selection: 'Inbox'),
      ),
    );
    expect(
      t.getSemantics(find.text('Tags')),
      matchesSemantics(
        label: 'Tags',
        isHeader: true,
        isButton: true,
        hasExpandedState: true,
        isExpanded: true,
        hasTapAction: true,
      ),
    );
    await t.tap(find.text('Tags'));
    await t.pumpAndSettle();
    expect(find.text('Work'), findsNothing);
    expect(
      t.getSemantics(find.text('Tags')),
      matchesSemantics(
        label: 'Tags',
        isHeader: true,
        isButton: true,
        hasExpandedState: true,
        isExpanded: false,
        hasTapAction: true,
      ),
    );
    await t.tap(find.text('Tags'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Work'), findsOneWidget); // mounted while opening
    await t.pumpAndSettle();
    handle.dispose();
  }, variant: ios);

  testWidgets('controlled isExpanded: reports, does not toggle itself', (
    t,
  ) async {
    shaderEnv();
    final calls = <bool>[];
    await t.pumpWidget(
      _host(
        GlassSidebarList<String>(
          sections: _sections(tags: false, onTags: calls.add),
        ),
      ),
    );
    expect(find.text('Work'), findsNothing);
    await t.tap(find.text('Tags'));
    await t.pumpAndSettle();
    expect(calls, [true]);
    expect(find.text('Work'), findsNothing);
  }, variant: ios);

  testWidgets('Reduce Motion collapses at once', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(
        GlassSidebarList<String>(sections: _sections()),
        reduceMotion: true,
      ),
    );
    await t.tap(find.text('Tags'));
    await t.pump();
    expect(find.text('Work'), findsNothing);
  }, variant: ios);

  testWidgets('the selection fills its row; separators beside it hide', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      _host(
        GlassSidebarList<String>(sections: _sections(), selection: 'Drafts'),
      ),
    );
    final ctx = t.element(find.text('Inbox'));
    final fill = CupertinoDynamicColor.resolve(GlassColors.listRowPressed, ctx);
    final sep = CupertinoDynamicColor.resolve(GlassColors.listSeparator, ctx);
    Iterable<ColoredBox> boxes(Color c) => t
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((b) => b.color == c);
    expect(boxes(fill), hasLength(1));
    // Library: Inbox|Drafts and Drafts|Sent hide; Tags: Work|Family shows.
    expect(boxes(sep), hasLength(1));
  }, variant: ios);

  testWidgets('RTL: header text at the start (right), chevron at the end', (
    t,
  ) async {
    shaderEnv();
    _size(t, const Size(402, 874));
    await t.pumpWidget(
      _host(
        GlassSidebarList<String>(sections: _sections()),
        direction: TextDirection.rtl,
      ),
    );
    final text = t.getRect(find.text('Library'));
    final chevron = t.getRect(find.byType(DisclosureChevron).first);
    expect(text.right, closeTo(402 - ListMetrics.margin - 16, 0.5));
    expect(chevron.center.dx, lessThan(text.left));
  }, variant: ios);

  testWidgets('dark: the platter takes the dark grouped colour', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _host(
        GlassSidebarList<String>(sections: _sections()),
        brightness: Brightness.dark,
      ),
    );
    final ctx = t.element(find.text('Inbox'));
    final platter = CupertinoDynamicColor.resolve(
      GlassColors.listSectionBackground,
      ctx,
    );
    expect(
      platter.toARGB32(),
      GlassColors.listSectionBackground.darkColor.toARGB32(),
    );
    final decorated = t
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<ShapeDecoration>()
        .where((d) => d.color == platter);
    expect(decorated, hasLength(2));
  }, variant: ios);

  testWidgets('Material path: ListTiles, selected tile, expand icon', (
    t,
  ) async {
    String? picked;
    await t.pumpWidget(
      _host(
        GlassSidebarList<String>(
          sections: _sections(),
          selection: 'Inbox',
          onSelectionChanged: (v) => picked = v,
        ),
      ),
    );
    expect(find.byType(ListTile), findsNWidgets(5));
    expect(t.widget<ListTile>(find.byType(ListTile).first).selected, isTrue);
    expect(find.byIcon(Icons.expand_less), findsNWidgets(2));
    await t.tap(find.text('Sent'));
    expect(picked, 'Sent');
    await t.tap(find.text('Tags'));
    await t.pumpAndSettle();
    expect(find.text('Work'), findsNothing);
  }, variant: android);

  testWidgets('in a compact split view a selection pushes the detail', (
    t,
  ) async {
    shaderEnv();
    _size(t, const Size(402, 800));
    await t.pumpWidget(
      MaterialApp(
        home: GlassSplitView(
          sidebar: GlassSidebarList<String>(
            sections: _sections(),
            onSelectionChanged: (_) {},
          ),
          detail: const Text('Detail'),
        ),
      ),
    );
    expect(find.text('Detail'), findsNothing);
    await t.tap(find.text('Sent'));
    await t.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  }, variant: ios);

  testWidgets('in a wide split view the sidebar uses the regular rows', (
    t,
  ) async {
    shaderEnv();
    _size(t, const Size(1194, 834));
    await t.pumpWidget(
      MaterialApp(
        home: GlassSplitView(
          sidebar: GlassSidebarList<String>(
            sections: _sections(),
            selection: 'Inbox',
            onSelectionChanged: (_) {},
          ),
          detail: const Text('Detail'),
        ),
      ),
    );
    expect(find.byType(GlassListTile), findsNothing);
    expect(find.text('Detail'), findsOneWidget);
    await t.tap(find.text('Family'));
    await t.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
  }, variant: ios);
}
