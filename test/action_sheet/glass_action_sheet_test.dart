import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/dialog/dialog_metrics.dart';
import 'package:adaptive_liquid_glass/src/dialog/glass_dialog_card.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(
  Future<void> Function(BuildContext) open, {
  TextDirection dir = TextDirection.ltr,
  bool reduceMotion = false,
}) => MaterialApp(
  builder: (_, child) => Directionality(
    textDirection: dir,
    child: reduceMotion
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          )
        : child!,
  ),
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

  testWidgets(
    'glass: a centred 240 card with title, message and stacked actions, no cancel drawn',
    (t) async {
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
      final card = t.getRect(find.byType(GlassDialogCard));
      expect(card.width, DialogMetrics.dialogWidth);
      expect(card.center, const Offset(400, 300));
      expect(find.text('Cancel'), findsNothing);
      final share = t.getCenter(find.text('Share'));
      final delete = t.getCenter(find.text('Delete'));
      expect(share.dy, lessThan(delete.dy));
      expect(share.dx, delete.dx);
      final title = t.getRect(find.text('Photo'));
      expect(
        title.left,
        closeTo(card.left + DialogMetrics.padding + DialogMetrics.textInset, 1),
      );
      expect(
        t.widget<Text>(find.text('Photo')).style?.fontWeight,
        FontWeight.w600,
      );
      await t.tap(find.text('Delete'));
      await t.pumpAndSettle();
      expect(find.byType(GlassDialogCard), findsNothing);
      expect(log, ['delete']);
      expect(result?.label, 'Delete');
    },
    variant: ios,
  );

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
    expect(find.byType(GlassDialogCard), findsNothing);
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
    expect(find.byType(GlassDialogCard), findsNothing);
    expect(log, isEmpty);
    expect(result, isNull);
  }, variant: ios);

  testWidgets('glass: only a cancel action is drawn as the button', (t) async {
    shaderEnv();
    GlassDialogAction? result;
    await t.pumpWidget(
      _app((context) async {
        result = await showGlassActionSheet(
          context: context,
          actions: const [],
          cancel: const GlassDialogAction(
            label: 'Cancel',
            role: GlassButtonRole.cancel,
          ),
        );
      }),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await t.pumpAndSettle();
    expect(find.byType(GlassDialogCard), findsNothing);
    expect(result?.label, 'Cancel');
  }, variant: ios);

  testWidgets('glass: semantics expose the buttons and the dismiss barrier', (
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
    expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
    t.semantics.tap(find.semantics.byLabel('Share'));
    await t.pumpAndSettle();
    expect(find.byType(GlassDialogCard), findsNothing);
    expect(result?.label, 'Share');
    s.dispose();
  }, variant: ios);

  testWidgets('glass: right to left puts the text at the start', (t) async {
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
    final card = t.getRect(find.byType(GlassDialogCard));
    expect(card.center, const Offset(400, 300));
    expect(
      t.getRect(find.text('Photo')).right,
      closeTo(card.right - DialogMetrics.padding - DialogMetrics.textInset, 1),
    );
    expect(t.takeException(), isNull);
  }, variant: ios);

  for (final reduceMotion in [false, true]) {
    testWidgets(
      'glass: ${reduceMotion ? 'Reduce Motion fades in' : 'scales in'}',
      (t) async {
        shaderEnv();
        await t.pumpWidget(
          _app(
            (context) => showGlassActionSheet(
              context: context,
              actions: const [GlassDialogAction(label: 'Share')],
            ),
            reduceMotion: reduceMotion,
          ),
        );
        await t.tap(find.text('Open'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(find.byType(GlassDialogCard), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(GlassDialogCard),
            matching: find.byType(ScaleTransition),
          ),
          reduceMotion ? findsNothing : findsWidgets,
        );
        await t.pumpAndSettle();
      },
      variant: ios,
    );
  }

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
