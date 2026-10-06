import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/menu/glass_menu_row.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(
  GlassMenuController c,
  List<String> picks, {
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  builder: (context, child) =>
      Directionality(textDirection: direction, child: child!),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: GlassMenuButton(
          controller: c,
          icon: CupertinoIcons.ellipsis,
          semanticLabel: 'More',
          items: [
            GlassMenuItem(label: 'Copy', onSelected: () => picks.add('copy')),
            const GlassMenuItem(label: 'Disabled', onSelected: null),
            GlassMenuItem(
              label: 'Delete',
              destructive: true,
              onSelected: () => picks.add('delete'),
            ),
          ],
        ),
      ),
    ),
  ),
);

GlassMenuRow _row(WidgetTester t, String label) => t.widget<GlassMenuRow>(
  find.ancestor(of: find.text(label), matching: find.byType(GlassMenuRow)),
);

Offset _rowCentre(WidgetTester t, String label) =>
    t.getCenter(find.text(label));

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('open shows the rows, close hides them', (t) async {
    shaderEnv();
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, []));
    expect(c.isOpen, false);
    c.open();
    await t.pumpAndSettle();
    expect(c.isOpen, true);
    expect(find.byType(GlassMenuRow), findsNWidgets(3));
    c.close();
    await t.pumpAndSettle();
    expect(c.isOpen, false);
    expect(find.byType(GlassMenuRow), findsNothing);
  }, variant: ios);

  testWidgets('glideTo highlights the row under the finger and clicks', (
    t,
  ) async {
    shaderEnv();
    final clicks = <Object?>[];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          clicks.add(call.arguments);
        }
        return null;
      },
    );
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, []));
    c.open();
    await t.pumpAndSettle();
    expect(c.glideTo(_rowCentre(t, 'Delete')), true);
    await t.pump();
    expect(_row(t, 'Delete').highlighted, true);
    expect(_row(t, 'Copy').highlighted, false);
    expect(_row(t, 'Disabled').highlighted, false);
    // Copy -> Delete -> Delete records two clicks (one per new row).
    clicks.clear();
    c.glideTo(_rowCentre(t, 'Copy'));
    c.glideTo(_rowCentre(t, 'Delete'));
    c.glideTo(_rowCentre(t, 'Delete'));
    expect(clicks, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
  }, variant: ios);

  testWidgets('gliding over a disabled row highlights nothing', (t) async {
    shaderEnv();
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, []));
    c.open();
    await t.pumpAndSettle();
    expect(c.glideTo(_rowCentre(t, 'Disabled')), true);
    await t.pump();
    expect(_row(t, 'Copy').highlighted, false);
    expect(_row(t, 'Disabled').highlighted, false);
    expect(_row(t, 'Delete').highlighted, false);
  }, variant: ios);

  testWidgets('gliding outside the menu returns false and clears', (t) async {
    shaderEnv();
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, []));
    c.open();
    await t.pumpAndSettle();
    c.glideTo(_rowCentre(t, 'Copy'));
    await t.pump();
    expect(c.glideTo(const Offset(5, 5)), false);
    await t.pump();
    expect(_row(t, 'Copy').highlighted, false);
  }, variant: ios);

  testWidgets('endGlide picks the highlighted row', (t) async {
    shaderEnv();
    final picks = <String>[];
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, picks));
    c.open();
    await t.pumpAndSettle();
    c.glideTo(_rowCentre(t, 'Copy'));
    await t.pump();
    expect(c.endGlide(), true);
    await t.pumpAndSettle();
    expect(picks, ['copy']);
    expect(find.byType(GlassMenuRow), findsNothing);
  }, variant: ios);

  testWidgets('endGlide with nothing highlighted leaves it open', (t) async {
    shaderEnv();
    final picks = <String>[];
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, picks));
    c.open();
    await t.pumpAndSettle();
    c.glideTo(_rowCentre(t, 'Disabled'));
    await t.pump();
    expect(c.endGlide(), false);
    await t.pumpAndSettle();
    expect(c.isOpen, true);
    expect(find.text('Copy'), findsOneWidget);
    expect(picks, isEmpty);
  }, variant: ios);

  testWidgets('cancelGlide clears the highlight and picks nothing', (t) async {
    shaderEnv();
    final picks = <String>[];
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, picks));
    c.open();
    await t.pumpAndSettle();
    c.glideTo(_rowCentre(t, 'Delete'));
    await t.pump();
    expect(_row(t, 'Delete').highlighted, true);
    c.cancelGlide();
    await t.pump();
    expect(_row(t, 'Delete').highlighted, false);
    expect(c.isOpen, true);
    expect(picks, isEmpty);
  }, variant: ios);

  testWidgets('glideTo while closed returns false', (t) async {
    shaderEnv();
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, []));
    expect(c.glideTo(const Offset(50, 50)), false);
    expect(c.endGlide(), false);
  }, variant: ios);

  testWidgets('RTL: gliding onto a row highlights it', (t) async {
    shaderEnv();
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, [], direction: TextDirection.rtl));
    c.open();
    await t.pumpAndSettle();
    expect(c.glideTo(_rowCentre(t, 'Delete')), true);
    await t.pump();
    expect(_row(t, 'Delete').highlighted, true);
    expect(_row(t, 'Copy').highlighted, false);
  }, variant: ios);

  testWidgets('Material: open and close drive the Material menu', (t) async {
    shaderEnv();
    final picks = <String>[];
    final c = GlassMenuController();
    await t.pumpWidget(_app(c, picks));
    expect(c.isOpen, false);
    c.open();
    await t.pumpAndSettle();
    expect(c.isOpen, true);
    expect(find.byType(MenuItemButton), findsNWidgets(3));
    c.close();
    await t.pumpAndSettle();
    expect(c.isOpen, false);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(c.glideTo(const Offset(50, 50)), false);
    expect(c.endGlide(), false);
    expect(picks, isEmpty);
  }, variant: android);
}
