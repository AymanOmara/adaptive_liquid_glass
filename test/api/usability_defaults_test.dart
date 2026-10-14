// The deprecated names are exercised on purpose: they must keep working.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

const _red = Color(0xFFFF0000);

const _tabs = [
  GlassTabBarItem(icon: CupertinoIcons.house, label: 'A'),
  GlassTabBarItem(icon: CupertinoIcons.gear, label: 'B'),
];

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('defaults', () {
    testWidgets('GlassMenuButton needs only its items', (t) async {
      shaderEnv();
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        appHost(
          GlassMenuButton(
            items: [GlassMenuItem(label: 'Copy', onSelected: () {})],
          ),
        ),
      );
      expect(find.byIcon(CupertinoIcons.ellipsis), findsOneWidget);
      expect(find.bySemanticsLabel('More'), findsOneWidget);
      handle.dispose();
    }, variant: ios);

    testWidgets('showGlassAlert without actions shows an OK button', (t) async {
      shaderEnv();
      GlassDialogAction? result;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async => result = await showGlassAlert(
                  context: context,
                  title: 'Saved',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(result?.label, 'OK');
    }, variant: ios);
  });

  group('tint is the accent colour everywhere', () {
    test('new name', () {
      expect(
        const GlassToggle(value: true, onChanged: null, tint: _red).tint,
        _red,
      );
      expect(
        const GlassSlider(value: 0, onChanged: null, tint: _red).tint,
        _red,
      );
      expect(
        const GlassRangeSlider(
          values: RangeValues(0, 1),
          onChanged: null,
          tint: _red,
        ).tint,
        _red,
      );
      expect(const GlassProgressIndicator(tint: _red).tint, _red);
      expect(const GlassProgressIndicator.circular(tint: _red).tint, _red);
      expect(
        const GlassPicker<int>(
          items: [GlassPickerItem(value: 0, label: 'A')],
          selected: 0,
          onChanged: null,
          tint: _red,
        ).tint,
        _red,
      );
      expect(const GlassChip(label: 'A', tint: _red).tint, _red);
      expect(
        GlassTabBar(
          items: _tabs,
          selectedIndex: 0,
          onSelected: (_) {},
          tint: _red,
        ).tint,
        _red,
      );
    });

    test('old names still work and read back', () {
      final toggle = const GlassToggle(
        value: true,
        onChanged: null,
        activeColor: _red,
      );
      expect((toggle.tint, toggle.activeColor), (_red, _red));
      final slider = const GlassSlider(
        value: 0,
        onChanged: null,
        activeColor: _red,
      );
      expect((slider.tint, slider.activeColor), (_red, _red));
      final range = const GlassRangeSlider(
        values: RangeValues(0, 1),
        onChanged: null,
        activeColor: _red,
      );
      expect((range.tint, range.activeColor), (_red, _red));
      const progress = GlassProgressIndicator(color: _red);
      expect((progress.tint, progress.color), (_red, _red));
      const ring = GlassProgressIndicator.circular(color: _red);
      expect((ring.tint, ring.color), (_red, _red));
      final picker = const GlassPicker<int>(
        items: [GlassPickerItem(value: 0, label: 'A')],
        selected: 0,
        onChanged: null,
        color: _red,
      );
      expect((picker.tint, picker.color), (_red, _red));
      const chip = GlassChip(label: 'A', selectedColor: _red);
      expect((chip.tint, chip.selectedColor), (_red, _red));
      final bar = GlassTabBar(
        items: _tabs,
        selectedIndex: 0,
        onSelected: (_) {},
        selectedColor: _red,
      );
      expect((bar.tint, bar.selectedColor), (_red, _red));
    });
  });
}
