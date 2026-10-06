import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/menu/glass_menu_panel.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(List<String> log) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: GlassContextMenu(
        items: [
          GlassMenuItem(
            label: 'Copy',
            icon: CupertinoIcons.doc_on_doc,
            onSelected: () => log.add('copy'),
          ),
          GlassMenuItem(
            label: 'Delete',
            icon: CupertinoIcons.trash,
            destructive: true,
            onSelected: () => log.add('delete'),
          ),
        ],
        child: const SizedBox(
          width: 200,
          height: 120,
          child: ColoredBox(color: Colors.white, child: Text('Card')),
        ),
      ),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a long-press opens the menu below the item; it picks', (
    t,
  ) async {
    shaderEnv();
    final log = <String>[];
    await t.pumpWidget(_app(log));
    final card = t.getRect(find.text('Card').first);
    await t.longPress(find.text('Card'));
    await t.pumpAndSettle();
    final panel = t.getRect(find.byType(GlassMenuPanel));
    expect(panel.top, greaterThan(card.top + 100));
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(find.byType(GlassMenuPanel), findsNothing);
    expect(log, ['delete']);
  }, variant: ios);

  testWidgets('a tap outside closes it without choosing', (t) async {
    shaderEnv();
    final log = <String>[];
    await t.pumpWidget(_app(log));
    await t.longPress(find.text('Card'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.byType(GlassMenuPanel), findsNothing);
    expect(log, isEmpty);
  }, variant: ios);

  testWidgets('Material: a popup menu', (t) async {
    shaderEnv();
    await t.pumpWidget(_app([]));
    await t.longPress(find.text('Card'));
    await t.pumpAndSettle();
    expect(find.byType(PopupMenuItem<GlassMenuItem>), findsNWidgets(2));
  }, variant: android);
}
