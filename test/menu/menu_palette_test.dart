import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/menu/menu_sections.dart';
import 'package:adaptive_liquid_glass/src/picker/picker_metrics.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _flags = [
  ('Red', CupertinoColors.systemRed),
  ('Orange', CupertinoColors.systemOrange),
  ('Yellow', CupertinoColors.systemYellow),
  ('Green', CupertinoColors.systemGreen),
  ('Blue', CupertinoColors.systemBlue),
];

List<GlassMenuItem> _items(
  List<String> picks, {
  int chosen = 1,
  GlassPickerStyle style = GlassPickerStyle.palette,
}) => [
  GlassMenuItem.picker(
    title: 'Flag',
    style: style,
    items: [
      for (var i = 0; i < _flags.length; i++)
        GlassMenuItem(
          label: _flags[i].$1,
          color: _flags[i].$2,
          checked: i == chosen,
          onSelected: () => picks.add(_flags[i].$1),
        ),
    ],
  ),
  GlassMenuItem(label: 'Mark as Read', onSelected: () => picks.add('read')),
];

Widget _app(
  List<String> picks, {
  GlassPickerStyle style = GlassPickerStyle.palette,
  GlassMenuController? controller,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GlassMenuButton(
          items: _items(picks, style: style),
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

  test('a palette is a titled section of its own, its swatches actions', () {
    final sections = menuSections(_items([]));
    expect(sections.map((s) => s.title), ['Flag', null]);
    expect(sections.first.rows.single.isPalette, isTrue);
    expect(menuActions(_items([])).map((r) => r.label), [
      for (final f in _flags) f.$1,
      'Mark as Read',
    ]);
  });

  test('a picker takes its style: inline a section, menu a submenu', () {
    final inline = _items([], style: GlassPickerStyle.inline).first;
    expect(inline.isSection, isTrue);
    expect(inline.isPalette || inline.isSubmenu, isFalse);
    final menu = _items([], style: GlassPickerStyle.menu).first;
    expect(menu.isSubmenu, isTrue);
    expect(menu.enabled, isTrue);
    expect(menu.label, 'Flag');
    final link = _items([], style: GlassPickerStyle.navigationLink).first;
    expect(link.isSubmenu, isTrue);
    final palette = _items([]).first;
    expect(palette.isPalette, isTrue);
    expect(palette.isSection || palette.isSubmenu || palette.enabled, isFalse);
    expect(palette.pickerStyle, GlassPickerStyle.palette);
  });

  testWidgets('the swatches sit side by side at the measured pitch', (t) async {
    shaderEnv();
    final picks = <String>[];
    await t.pumpWidget(_app(picks));
    await _open(t);
    expect(find.text('Flag'), findsOneWidget);
    final red = t.getCenter(find.bySemanticsLabel('Red'));
    final orange = t.getCenter(find.bySemanticsLabel('Orange'));
    final blue = t.getCenter(find.bySemanticsLabel('Blue'));
    expect(orange.dx - red.dx, closeTo(PickerMetrics.paletteSwatchPitch, .01));
    expect(orange.dy, red.dy);
    // Centred in the menu: as far from its edges on both sides.
    final menu = t.getRect(
      find
          .ancestor(
            of: find.bySemanticsLabel('Red'),
            matching: find.byType(SizedBox),
          )
          .last,
    );
    expect(red.dx - menu.left, closeTo(menu.right - blue.dx, .5));
    final title = t.getRect(find.text('Flag'));
    expect(red.dy, greaterThan(title.bottom));
    // The chosen swatch reads as selected.
    expect(
      t.getSemantics(find.bySemanticsLabel('Orange')),
      isSemantics(isSelected: true, isButton: true),
    );
    await t.tapAt(t.getCenter(find.bySemanticsLabel('Green')));
    await t.pumpAndSettle();
    expect(picks, ['Green']);
    expect(find.text('Flag'), findsNothing);
  }, variant: ios);

  testWidgets('no separator line under the swatch row', (t) async {
    shaderEnv();
    await t.pumpWidget(_app([]));
    await _open(t);
    final separator = CupertinoDynamicColor.resolve(
      GlassColors.menuSeparator,
      t.element(find.text('Flag')),
    );
    // SwiftUI draws the palette straight into the next section.
    expect(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == separator),
      findsNothing,
    );
  }, variant: ios);

  testWidgets('a glide over a swatch chooses it', (t) async {
    shaderEnv();
    final picks = <String>[];
    final controller = GlassMenuController();
    await t.pumpWidget(_app(picks, controller: controller));
    controller.open();
    await t.pumpAndSettle();
    expect(
      controller.glideTo(t.getCenter(find.bySemanticsLabel('Blue'))),
      isTrue,
    );
    controller.endGlide();
    await t.pumpAndSettle();
    expect(picks, ['Blue']);
  }, variant: ios);

  testWidgets('Material: the palette is a row of icon buttons', (t) async {
    final picks = <String>[];
    await t.pumpWidget(_app(picks));
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    IconButton swatch(String name) => t.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(name),
        matching: find.byType(IconButton),
      ),
    );
    for (final f in _flags) {
      expect(swatch(f.$1).isSelected, f.$1 == 'Orange');
    }
    await t.tap(find.byTooltip('Red'));
    await t.pumpAndSettle();
    expect(picks, ['Red']);
    expect(find.byTooltip('Red'), findsNothing);
  }, variant: android);
}
