import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// Large text (Dynamic Type / `MediaQuery.textScaler`) audit: every public
/// component is pumped on the shader path and the Material path at 2x and
/// 3x in a phone-sized view, and must lay out without overflow.
/// Content components must show their text in full; fixed-height chrome
/// clamps its text scale, as iOS does.

const _phone = Size(390, 844);

const _long = 'Large text should wrap instead of overflowing';

final _first = DateTime(2020);
final _last = DateTime(2030, 12, 31);
final _day = DateTime(2026, 10, 12, 9, 30);

/// A case: what to pump, an optional step that opens an overlay, and the
/// texts that must render in full (not ellipsised or cut to fewer lines).
class _Case {
  const _Case(this.name, this.build, {this.open, this.full = const []});

  final String name;
  final Widget Function(BuildContext context) build;
  final Future<void> Function(WidgetTester t)? open;
  final List<String> full;
}

Widget _opener(void Function(BuildContext) open) => Builder(
  builder: (context) =>
      TextButton(onPressed: () => open(context), child: const Text('Open')),
);

Future<void> _tapOpen(WidgetTester t) async {
  await t.tap(find.text('Open'));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

final _cases = <_Case>[
  _Case(
    'GlassButton',
    (_) => GlassButton(onPressed: () {}, child: const Text(_long)),
    full: [_long],
  ),
  _Case(
    'GlassButton.icon',
    (_) => GlassButton.icon(
      onPressed: () {},
      icon: CupertinoIcons.add,
      label: const Text('Add item'),
    ),
    full: ['Add item'],
  ),
  _Case(
    'GlassFloatingActionButton.extended',
    (_) => GlassFloatingActionButton.extended(
      onPressed: () {},
      icon: CupertinoIcons.pencil,
      label: const Text('Compose'),
    ),
    full: ['Compose'],
  ),
  _Case(
    'GlassChip',
    (_) => GlassChip(
      label: 'Favourites',
      icon: CupertinoIcons.star,
      onSelected: (_) {},
      onDeleted: () {},
    ),
  ),
  _Case('GlassBadge', (_) => const GlassBadge(label: '99+')),
  _Case(
    'GlassLabel',
    (_) => GlassLabel.text(text: 'Settings', icon: CupertinoIcons.gear),
  ),
  _Case(
    'GlassLink',
    (_) => GlassLink(
      destination: Uri.parse('https://example.com'),
      label: 'Open the website',
      onOpen: (_) {},
    ),
  ),
  _Case(
    'GlassShareLink',
    (_) => GlassShareLink(onShare: () {}, label: 'Share'),
  ),
  _Case(
    'GlassSegmentedControl',
    (_) => GlassSegmentedControl<int>(
      segments: const [
        GlassSegment(value: 0, label: Text('Day')),
        GlassSegment(value: 1, label: Text('Week')),
        GlassSegment(value: 2, label: Text('Month')),
      ],
      selected: 0,
      onChanged: (_) {},
    ),
  ),
  _Case('GlassToggle', (_) => GlassToggle(value: true, onChanged: (_) {})),
  _Case('GlassSlider', (_) => GlassSlider(value: .5, onChanged: (_) {})),
  _Case('GlassStepper', (_) => GlassStepper(value: 5, onChanged: (_) {})),
  _Case(
    'GlassListSection',
    (_) => GlassListSection(
      header: const Text('Header'),
      footer: const Text(_long),
      children: [
        GlassListTile(
          title: const Text(_long),
          subtitle: const Text('Subtitle that is also fairly long'),
          leading: const Icon(CupertinoIcons.wifi),
          value: 'On',
          chevron: true,
          onTap: () {},
        ),
        GlassListTile(
          title: const Text('Airplane mode'),
          trailing: GlassToggle(value: false, onChanged: (_) {}),
        ),
      ],
    ),
    full: [_long],
  ),
  _Case(
    'GlassTextField',
    (_) => const GlassTextField(placeholder: 'Email', errorText: _long),
  ),
  _Case(
    'GlassSearchField',
    (_) => const GlassSearchField(placeholder: 'Search'),
  ),
  _Case(
    'GlassSearchSuggestionRow',
    (_) => GlassSearchSuggestionRow(
      suggestion: const GlassSearchSuggestion(
        title: Text('Suggestion'),
        subtitle: Text('Detail'),
      ),
      onTap: () {},
    ),
  ),
  _Case(
    'GlassToolbar',
    (_) => GlassToolbar(
      children: [
        GlassButton.icon(onPressed: () {}, icon: CupertinoIcons.share),
        const GlassToolbarSpacer(),
        GlassButton(onPressed: () {}, child: const Text('Done')),
      ],
    ),
  ),
  _Case(
    'GlassEmptyState',
    (_) => GlassEmptyState(
      icon: const Icon(CupertinoIcons.tray),
      title: const Text('No messages'),
      description: const Text(_long),
      actions: [GlassButton(onPressed: () {}, child: const Text('Refresh'))],
    ),
    full: [_long],
  ),
  _Case(
    'GlassDisclosureGroup',
    (_) => const GlassDisclosureGroup(
      label: Text(_long),
      initiallyExpanded: true,
      children: [Text('Child')],
    ),
    full: [_long],
  ),
  _Case(
    'GlassPageControl',
    (_) => const GlassPageControl(count: 5, currentPage: 0),
  ),
  _Case(
    'GlassGauge',
    (_) => const GlassGauge(
      value: .4,
      label: Text('Storage'),
      currentValueLabel: Text('40%'),
      minimumValueLabel: Text('0'),
      maximumValueLabel: Text('100'),
    ),
  ),
  _Case(
    'GlassGauge.circular',
    (_) => const GlassGauge(
      value: .4,
      style: GlassGaugeStyle.accessoryCircular,
      currentValueLabel: Text('40'),
    ),
  ),
  _Case(
    'GlassProgressIndicator',
    (_) => const GlassProgressIndicator(value: .3),
  ),
  _Case('GlassActivityIndicator', (_) => const GlassActivityIndicator()),
  _Case(
    'GlassPicker',
    (_) => GlassPicker<int>(
      items: const [
        GlassPickerItem(value: 0, label: 'Alphabetical'),
        GlassPickerItem(value: 1, label: 'Date'),
      ],
      selected: 0,
      onChanged: (_) {},
      label: const Text('Sort by'),
    ),
  ),
  _Case(
    'GlassPicker.segmented',
    (_) => GlassPicker<int>(
      items: const [
        GlassPickerItem(value: 0, label: 'List'),
        GlassPickerItem(value: 1, label: 'Grid'),
      ],
      selected: 0,
      onChanged: (_) {},
      style: GlassPickerStyle.inline,
    ),
  ),
  _Case(
    'GlassWheelPicker',
    (_) => GlassWheelPicker<int>(
      items: const [
        GlassPickerItem(value: 0, label: 'One'),
        GlassPickerItem(value: 1, label: 'Two'),
      ],
      selected: 0,
      onChanged: (_) {},
    ),
  ),
  _Case(
    'GlassDatePicker.compact',
    (_) => GlassDatePicker(
      value: _day,
      onChanged: (_) {},
      firstDate: _first,
      lastDate: _last,
      pickerMode: GlassDatePickerMode.dateAndTime,
    ),
  ),
  _Case(
    'GlassCalendar',
    (_) => GlassCalendar(
      selected: _day,
      onSelected: (_) {},
      firstDate: _first,
      lastDate: _last,
    ),
  ),
  _Case(
    'GlassDateWheel',
    (_) => GlassDateWheel(
      value: _day,
      onChanged: (_) {},
      firstDate: _first,
      lastDate: _last,
    ),
  ),
  _Case(
    'GlassColorPicker',
    (_) => GlassColorPicker(
      value: Colors.teal,
      onChanged: (_) {},
      label: const Text('Colour'),
    ),
  ),
  _Case(
    'GlassNavigationBar',
    (_) => const SizedBox(
      width: 390,
      child: GlassNavigationBar(title: Text('A rather long title')),
    ),
  ),
  _Case(
    'GlassTabBar',
    (_) => SizedBox(
      width: 390,
      child: GlassTabBar(
        items: const [
          GlassTabBarItem(icon: CupertinoIcons.home, label: 'Home'),
          GlassTabBarItem(icon: CupertinoIcons.search, label: 'Search'),
          GlassTabBarItem(icon: CupertinoIcons.settings, label: 'Settings'),
        ],
        selectedIndex: 0,
        onSelected: (_) {},
      ),
    ),
  ),
  _Case(
    'GlassSwipeActions',
    (_) => GlassSwipeActions(
      trailing: [
        GlassSwipeAction(
          icon: CupertinoIcons.trash,
          label: 'Delete',
          onPressed: () {},
        ),
      ],
      child: const SizedBox(height: 60, child: Text('Row')),
    ),
  ),
  _Case(
    'showGlassAlert',
    (_) => _opener(
      (context) => showGlassAlert(
        context: context,
        title: _long,
        message: _long,
        actions: const [
          GlassDialogAction(label: 'Cancel', role: GlassButtonRole.cancel),
          GlassDialogAction(label: 'Delete everything'),
        ],
      ),
    ),
    open: _tapOpen,
    full: ['Cancel', 'Delete everything'],
  ),
  _Case(
    'showGlassConfirmationDialog',
    (_) => _opener(
      (context) => showGlassConfirmationDialog(
        context: context,
        title: _long,
        actions: const [
          GlassDialogAction(label: 'Share'),
          GlassDialogAction(label: 'Delete', role: GlassButtonRole.destructive),
        ],
      ),
    ),
    open: _tapOpen,
    full: ['Share', 'Delete'],
  ),
  _Case(
    'showGlassActionSheet',
    (_) => _opener(
      (context) => showGlassActionSheet(
        context: context,
        title: 'Photo',
        message: _long,
        actions: const [GlassDialogAction(label: 'Save to Files')],
        cancel: const GlassDialogAction(
          label: 'Cancel',
          role: GlassButtonRole.cancel,
        ),
      ),
    ),
    open: _tapOpen,
    full: ['Save to Files'],
  ),
  _Case(
    'showGlassSheet',
    (_) => _opener(
      (context) => showGlassSheet<void>(
        context: context,
        builder: (_) => const Text(_long),
      ),
    ),
    open: _tapOpen,
    full: [_long],
  ),
  _Case(
    'showGlassPopover',
    (_) => _opener(
      (context) => showGlassPopover<void>(
        context: context,
        builder: (_) => const Text('Popover content'),
      ),
    ),
    open: _tapOpen,
    full: ['Popover content'],
  ),
  _Case(
    'showGlassToast',
    (_) => _opener(
      (context) => showGlassToast(
        context,
        message: _long,
        icon: CupertinoIcons.check_mark,
        action: GlassToastAction(label: 'Undo', onPressed: () {}),
        duration: null,
      ),
    ),
    open: _tapOpen,
    full: [_long, 'Undo'],
  ),
  _Case(
    'GlassMenuButton',
    (_) => GlassMenuButton(
      icon: CupertinoIcons.ellipsis,
      semanticLabel: 'More',
      items: [
        GlassMenuItem(
          label: 'Duplicate this item',
          icon: CupertinoIcons.plus_square_on_square,
          onSelected: () {},
        ),
        GlassMenuItem(
          label: 'Delete',
          icon: CupertinoIcons.trash,
          destructive: true,
          onSelected: () {},
        ),
      ],
    ),
    open: (t) async {
      await t.tap(find.byType(GlassMenuButton));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    },
    full: ['Duplicate this item', 'Delete'],
  ),
  _Case(
    'GlassContextMenu',
    (_) => GlassContextMenu(
      items: [
        GlassMenuItem(
          label: 'Copy',
          icon: CupertinoIcons.doc_on_doc,
          onSelected: () {},
        ),
      ],
      child: const Padding(
        padding: EdgeInsets.all(24),
        // A style of its own: the lifted preview sits on iOS page text.
        child: Text(
          'Card',
          style: TextStyle(fontSize: 14, height: 1.2, letterSpacing: 0),
        ),
      ),
    ),
    open: (t) async {
      await t.longPress(find.text('Card'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
    },
    full: ['Copy'],
  ),
];

Widget _host(double scale, _Case c) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 16,
          vertical: 60,
        ),
        child: Center(child: Builder(builder: c.build)),
      ),
    ),
  ),
);

/// Every paragraph of [text] lays out in full: not cut to fewer lines.
void _expectFull(WidgetTester t, String text, String where) {
  final found = find.text(text, findRichText: true);
  expect(found, findsWidgets, reason: '$where: "$text" is missing');
  for (final element in found.evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph) continue;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '$where: "$text" is truncated',
    );
  }
}

/// No paragraph is laid out shorter than its lines: a fixed-height box
/// would cut the text off top and bottom.
void _expectNoClippedLines(WidgetTester t, String where) {
  for (final paragraph in t.allRenderObjects.whereType<RenderParagraph>()) {
    if (!paragraph.hasSize || paragraph.size.isEmpty) continue;
    final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(needed - 0.5),
      reason: '$where: "${paragraph.text.toPlainText()}" is cut off',
    );
  }
  for (final editable in t.allRenderObjects.whereType<RenderEditable>()) {
    expect(
      editable.size.height,
      greaterThanOrEqualTo(editable.preferredLineHeight - 0.5),
      reason: '$where: a text field is cut off',
    );
  }
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  for (final (path, variant) in [('shader', ios), ('Material', android)]) {
    for (final c in _cases) {
      for (final scale in [2.0, 3.0]) {
        testWidgets('$path: ${c.name} at ${scale}x lays out', (t) async {
          shaderEnv();
          t.view.physicalSize = _phone * t.view.devicePixelRatio;
          addTearDown(t.view.reset);
          await t.pumpWidget(_host(scale, c));
          await t.pump(const Duration(seconds: 1));
          expect(t.takeException(), isNull, reason: c.name);
          if (c.open != null) {
            await c.open!(t);
            expect(t.takeException(), isNull, reason: '${c.name} (open)');
          }
          for (final text in c.full) {
            _expectFull(t, text, '${c.name} at ${scale}x');
          }
          _expectNoClippedLines(t, '${c.name} at ${scale}x');
          // Let toasts and timers finish before the test ends.
          await t.pumpWidget(const SizedBox());
          await t.pump(const Duration(seconds: 10));
        }, variant: variant);
      }
    }
  }

  // Fixed-height chrome keeps its text at the default size, as iOS's.
  for (final (name, label) in [
    ('GlassTabBar', 'Search'),
    ('GlassNavigationBar', 'A rather long title'),
    ('GlassSegmentedControl', 'Week'),
    ('GlassWheelPicker', 'One'),
    ('GlassBadge', '99+'),
  ]) {
    testWidgets('shader: $name keeps its text size at 3x', (t) async {
      shaderEnv();
      t.view.physicalSize = _phone * t.view.devicePixelRatio;
      addTearDown(t.view.reset);
      final c = _cases.firstWhere((c) => c.name == name);
      Future<Size> sizeAt(double scale) async {
        await t.pumpWidget(_host(scale, c));
        await t.pump(const Duration(seconds: 1));
        return t.getSize(find.text(label).first);
      }

      final normal = await sizeAt(1);
      expect(await sizeAt(3), normal);
    }, variant: ios);
  }
}
