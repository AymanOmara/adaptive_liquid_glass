import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/menu/glass_menu_row.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(List<String> picks, {Alignment at = Alignment.topRight}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: at,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GlassMenuButton(
              icon: CupertinoIcons.ellipsis,
              semanticLabel: 'More',
              items: [
                GlassMenuItem(
                  label: 'Copy',
                  onSelected: () => picks.add('copy'),
                ),
                GlassMenuItem(
                  label: 'Delete',
                  icon: CupertinoIcons.trash,
                  destructive: true,
                  onSelected: () => picks.add('delete'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('opens over the button from its top end corner, and picks', (
    t,
  ) async {
    shaderEnv();
    final picks = <String>[];
    await t.pumpWidget(_app(picks));
    expect(find.text('Copy'), findsNothing);
    await t.tap(find.bySemanticsLabel('More'));
    await t.pumpAndSettle();
    final button = t.getRect(find.bySemanticsLabel('More'));
    final menu = t.getRect(
      find.ancestor(of: find.text('Copy'), matching: find.byType(LiquidGlass)),
    );
    // As SwiftUI's Menu: the menu covers its button.
    expect(menu.top, moreOrLessEquals(button.top, epsilon: 0.5));
    expect(menu.right, moreOrLessEquals(button.right, epsilon: 0.5));
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(picks, ['delete']);
    expect(find.text('Copy'), findsNothing);
  }, variant: ios);

  testWidgets('near the bottom it opens upwards from the bottom corner', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_app([], at: Alignment.bottomLeft));
    await t.tap(find.bySemanticsLabel('More'));
    await t.pumpAndSettle();
    final button = t.getRect(find.bySemanticsLabel('More'));
    final menu = t.getRect(
      find.ancestor(of: find.text('Copy'), matching: find.byType(LiquidGlass)),
    );
    expect(menu.bottom, moreOrLessEquals(button.bottom, epsilon: 0.5));
    expect(menu.left, moreOrLessEquals(button.left, epsilon: 0.5));
  }, variant: ios);

  testWidgets('tapping outside closes it without choosing', (t) async {
    shaderEnv();
    final picks = <String>[];
    await t.pumpWidget(_app(picks));
    await t.tap(find.bySemanticsLabel('More'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(100, 500));
    await t.pumpAndSettle();
    expect(find.byType(GlassMenuRow), findsNothing);
    expect(picks, isEmpty);
  }, variant: ios);

  testWidgets('a destructive item is red', (t) async {
    shaderEnv();
    await t.pumpWidget(_app([]));
    await t.tap(find.bySemanticsLabel('More'));
    await t.pumpAndSettle();
    final style = t.widget<Text>(find.text('Delete')).style!;
    expect(style.color!.toARGB32(), GlassColors.systemRed.color.toARGB32());
  }, variant: ios);

  testWidgets('Material: a Material 3 menu', (t) async {
    shaderEnv();
    final picks = <String>[];
    await t.pumpWidget(_app(picks));
    await t.tap(find.byType(IconButton));
    await t.pumpAndSettle();
    expect(find.byType(MenuItemButton), findsNWidgets(2));
    await t.tap(find.text('Copy'));
    await t.pumpAndSettle();
    expect(picks, ['copy']);
  }, variant: android);

  testWidgets('in a bar the menu does not merge with the buttons', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: GlassNavigationBar(
            actions: [
              GlassMenuButton(
                icon: CupertinoIcons.ellipsis,
                semanticLabel: 'More',
                items: [GlassMenuItem(label: 'Copy', onSelected: () {})],
              ),
            ],
          ),
        ),
      ),
    );
    await t.tap(find.bySemanticsLabel('More'));
    await t.pumpAndSettle();
    final menuGroup = find.ancestor(
      of: find.text('Copy'),
      matching: find.byType(GlassGroup),
    );
    final buttonGroup = find.ancestor(
      of: find.bySemanticsLabel('More'),
      matching: find.byType(GlassGroup),
    );
    expect(t.element(menuGroup.first), isNot(t.element(buttonGroup.first)));
  }, variant: ios);
}
