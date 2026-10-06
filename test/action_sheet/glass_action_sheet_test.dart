import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/action_sheet/action_sheet_metrics.dart';
import 'package:adaptive_liquid_glass/src/action_sheet/glass_action_sheet_card.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(
  Future<void> Function(BuildContext) open, {
  TextDirection dir = TextDirection.ltr,
}) => MaterialApp(
  builder: (_, child) => Directionality(textDirection: dir, child: child!),
  home: Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () => open(context),
        child: const Text('Open'),
      ),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('glass: a bottom card with title, actions and cancel', (t) async {
    shaderEnv();
    final log = <String>[];
    GlassDialogAction? result;
    await t.pumpWidget(
      _app((context) async {
        result = await showGlassActionSheet(
          context: context,
          title: 'Photo',
          message: 'What would you like to do with it?',
          actions: [
            GlassDialogAction(
              label: 'Share',
              onPressed: () => log.add('share'),
            ),
            GlassDialogAction(
              label: 'Delete',
              role: GlassButtonRole.destructive,
              onPressed: () => log.add('delete'),
            ),
          ],
          cancel: GlassDialogAction(
            label: 'Cancel',
            role: GlassButtonRole.cancel,
            onPressed: () => log.add('cancel'),
          ),
        );
      }),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final card = t.getRect(find.byType(GlassActionSheetCard));
    // The 800 x 600 test screen has no safe area: the card floats 8 pt
    // above the bottom, centred, at its widest.
    expect(card.bottom, closeTo(600 - ActionSheetMetrics.margin, 1));
    expect(card.center.dx, 400);
    expect(card.width, ActionSheetMetrics.maxWidth);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('What would you like to do with it?'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(
      t.getCenter(find.text('Share')).dy,
      lessThan(t.getCenter(find.text('Cancel')).dy),
    );
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(find.byType(GlassActionSheetCard), findsNothing);
    expect(log, ['delete']);
    expect(result?.label, 'Delete');
  }, variant: ios);

  testWidgets('glass: a destructive label is red', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        (context) => showGlassActionSheet(
          context: context,
          actions: [
            const GlassDialogAction(
              label: 'Delete',
              role: GlassButtonRole.destructive,
            ),
          ],
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final delete = find.text('Delete');
    expect(
      t.widget<Text>(delete).style?.color,
      CupertinoDynamicColor.resolve(GlassSystemColors.red, t.element(delete)),
    );
  }, variant: ios);

  testWidgets('glass: a tap outside takes the cancel action', (t) async {
    shaderEnv();
    final log = <String>[];
    GlassDialogAction? result;
    await t.pumpWidget(
      _app((context) async {
        result = await showGlassActionSheet(
          context: context,
          actions: const [GlassDialogAction(label: 'Share')],
          cancel: GlassDialogAction(
            label: 'Cancel',
            role: GlassButtonRole.cancel,
            onPressed: () => log.add('cancel'),
          ),
        );
      }),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(20, 20));
    await t.pumpAndSettle();
    expect(find.byType(GlassActionSheetCard), findsNothing);
    expect(log, ['cancel']);
    expect(result?.label, 'Cancel');
  }, variant: ios);

  testWidgets('glass: without cancel a tap outside completes with null', (
    t,
  ) async {
    shaderEnv();
    final log = <String>[];
    GlassDialogAction? result;
    await t.pumpWidget(
      _app((context) async {
        result = await showGlassActionSheet(
          context: context,
          actions: [
            GlassDialogAction(
              label: 'Share',
              onPressed: () => log.add('share'),
            ),
          ],
        );
      }),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(20, 20));
    await t.pumpAndSettle();
    expect(find.byType(GlassActionSheetCard), findsNothing);
    expect(log, isEmpty);
    expect(result, isNull);
  }, variant: ios);

  testWidgets('glass: semantics expose the buttons and pick through them', (
    t,
  ) async {
    shaderEnv();
    GlassDialogAction? result;
    await t.pumpWidget(
      _app((context) async {
        result = await showGlassActionSheet(
          context: context,
          actions: const [GlassDialogAction(label: 'Share')],
          cancel: const GlassDialogAction(
            label: 'Cancel',
            role: GlassButtonRole.cancel,
          ),
        );
      }),
    );
    final s = t.ensureSemantics();
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(
      t.getSemantics(find.text('Share')),
      matchesSemantics(label: 'Share', isButton: true, hasTapAction: true),
    );
    expect(
      t.getSemantics(find.text('Cancel')),
      matchesSemantics(label: 'Cancel', isButton: true, hasTapAction: true),
    );
    t.semantics.tap(find.semantics.byLabel('Share'));
    await t.pumpAndSettle();
    expect(find.byType(GlassActionSheetCard), findsNothing);
    expect(result?.label, 'Share');
    s.dispose();
  }, variant: ios);

  testWidgets('glass: right to left renders', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        (context) => showGlassActionSheet(
          context: context,
          title: 'Photo',
          message: 'What would you like to do with it?',
          actions: const [GlassDialogAction(label: 'Share')],
          cancel: const GlassDialogAction(
            label: 'Cancel',
            role: GlassButtonRole.cancel,
          ),
        ),
        dir: TextDirection.rtl,
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final card = t.getRect(find.byType(GlassActionSheetCard));
    expect(card.bottom, closeTo(600 - ActionSheetMetrics.margin, 1));
    expect(card.center.dx, 400);
    expect(t.getCenter(find.text('Photo')).dx, closeTo(400, 1));
    expect(t.takeException(), isNull);
  }, variant: ios);

  testWidgets('Material: a modal bottom sheet with a list', (t) async {
    shaderEnv();
    GlassDialogAction? result;
    await t.pumpWidget(
      _app((context) async {
        result = await showGlassActionSheet(
          context: context,
          title: 'Photo',
          actions: const [GlassDialogAction(label: 'Share')],
          cancel: const GlassDialogAction(
            label: 'Cancel',
            role: GlassButtonRole.cancel,
          ),
        );
      }),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('Photo'), findsOneWidget);
    await t.tap(find.text('Share'));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(result?.label, 'Share');
  }, variant: android);
}
