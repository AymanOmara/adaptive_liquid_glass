import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/dialog/glass_dialog_card.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(Future<void> Function(BuildContext) open) => MaterialApp(
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

  testWidgets('alert: a 320 card, two buttons side by side, runs the action', (
    t,
  ) async {
    shaderEnv();
    final log = <String>[];
    GlassDialogAction? result;
    await t.pumpWidget(
      _app(
        (context) async => result = await showGlassAlert(
          context: context,
          title: 'Delete photo?',
          message: 'It will be deleted.',
          actions: [
            const GlassDialogAction(
              label: 'Cancel',
              role: GlassButtonRole.cancel,
            ),
            GlassDialogAction(
              label: 'Delete',
              role: GlassButtonRole.destructive,
              onPressed: () => log.add('delete'),
            ),
          ],
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final card = t.getRect(find.byType(GlassDialogCard));
    expect(card.width, 320);
    expect(card.center, t.getCenter(find.byType(Navigator)));
    final cancel = t.getRect(find.text('Cancel'));
    final delete = t.getRect(find.text('Delete'));
    expect(cancel.center.dy, moreOrLessEquals(delete.center.dy));
    expect(cancel.center.dx, lessThan(delete.center.dx));
    // A tap outside does not close an alert.
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.byType(GlassDialogCard), findsOneWidget);
    await t.tap(find.text('Delete'));
    await t.pumpAndSettle();
    expect(find.byType(GlassDialogCard), findsNothing);
    expect(log, ['delete']);
    expect(result?.label, 'Delete');
  }, variant: ios);

  testWidgets('confirmation: stacked, cancel hidden and taken outside', (
    t,
  ) async {
    shaderEnv();
    final log = <String>[];
    await t.pumpWidget(
      _app(
        (context) => showGlassConfirmationDialog(
          context: context,
          title: 'Photo',
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
            GlassDialogAction(
              label: 'Cancel',
              role: GlassButtonRole.cancel,
              onPressed: () => log.add('cancel'),
            ),
          ],
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(GlassDialogCard)).width, 240);
    expect(find.text('Cancel'), findsNothing);
    expect(
      t.getCenter(find.text('Share')).dy,
      lessThan(t.getCenter(find.text('Delete')).dy),
    );
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    expect(find.byType(GlassDialogCard), findsNothing);
    expect(log, ['cancel']);
  }, variant: ios);

  testWidgets('Material: an AlertDialog', (t) async {
    shaderEnv();
    await t.pumpWidget(
      _app(
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  }, variant: android);
}
