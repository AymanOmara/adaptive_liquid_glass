import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/dialog/glass_dialog_card.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
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

Future<void> _open(
  WidgetTester t,
  Future<void> Function(BuildContext) open,
) async {
  await t.pumpWidget(_app(open));
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
}

const _cancel = GlassDialogAction(
  label: 'Cancel',
  role: GlassButtonRole.cancel,
);
const _delete = GlassDialogAction(
  label: 'Delete',
  role: GlassButtonRole.destructive,
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('W9 alert content and icon', () {
    testWidgets('glass: icon above the title, content under the message', (
      t,
    ) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          message: 'Message',
          icon: const Icon(Icons.star, key: Key('icon')),
          content: const SizedBox(height: 30, key: Key('content')),
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      );
      final icon = t.getRect(find.byKey(const Key('icon')));
      final title = t.getRect(find.text('Title'));
      final message = t.getRect(find.text('Message'));
      final content = t.getRect(find.byKey(const Key('content')));
      final ok = t.getRect(find.text('OK'));
      expect(icon.bottom, lessThanOrEqualTo(title.top));
      expect(message.bottom, lessThanOrEqualTo(content.top));
      expect(content.bottom, lessThan(ok.top));
      final card = t.getRect(find.byType(GlassDialogCard));
      expect(content.width, card.width - 2 * 16);
    }, variant: ios);

    testWidgets('glass: content instead of a message', (t) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          content: const Text('Custom'),
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      );
      expect(find.text('Custom'), findsOneWidget);
      expect(
        t.getRect(find.text('Title')).bottom,
        lessThan(t.getRect(find.text('Custom')).top),
      );
    }, variant: ios);

    testWidgets('Material: AlertDialog icon, message and content', (t) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          message: 'Message',
          icon: const Icon(Icons.star, key: Key('icon')),
          content: const Text('Custom'),
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      );
      final dialog = t.widget<AlertDialog>(find.byType(AlertDialog));
      expect(dialog.icon, isNotNull);
      expect(find.byKey(const Key('icon')), findsOneWidget);
      expect(
        t.getRect(find.text('Message')).bottom,
        lessThanOrEqualTo(t.getRect(find.text('Custom')).top),
      );
    }, variant: android);
  });

  group('W9 barrierDismissible', () {
    testWidgets('glass: true lets a tap outside close it with null', (t) async {
      shaderEnv();
      GlassDialogAction? got = const GlassDialogAction(label: 'unset');
      await _open(t, (context) async {
        got = await showGlassAlert(
          context: context,
          title: 'Title',
          barrierDismissible: true,
          actions: const [GlassDialogAction(label: 'OK')],
        );
      });
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(find.byType(GlassDialogCard), findsNothing);
      expect(got, isNull);
    }, variant: ios);

    testWidgets('Material: default closes outside, false does not', (t) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      );
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Again',
          barrierDismissible: false,
          actions: const [GlassDialogAction(label: 'OK')],
        ),
      );
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    }, variant: android);
  });

  group('W9 action order', () {
    testWidgets('glass: given order by default', (t) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actions: const [_delete, _cancel],
        ),
      );
      expect(
        t.getCenter(find.text('Delete')).dx,
        lessThan(t.getCenter(find.text('Cancel')).dx),
      );
    }, variant: ios);

    testWidgets('glass: platform order puts cancel leading side by side', (
      t,
    ) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actionOrder: GlassAlertActionOrder.platform,
          actions: const [_delete, _cancel],
        ),
      );
      expect(
        t.getCenter(find.text('Cancel')).dx,
        lessThan(t.getCenter(find.text('Delete')).dx),
      );
    }, variant: ios);

    testWidgets('glass: platform order puts cancel last when stacked', (
      t,
    ) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actionOrder: GlassAlertActionOrder.platform,
          actions: const [
            _cancel,
            GlassDialogAction(label: 'Keep'),
            _delete,
          ],
        ),
      );
      expect(
        t.getCenter(find.text('Cancel')).dy,
        greaterThan(t.getCenter(find.text('Delete')).dy),
      );
    }, variant: ios);

    testWidgets('Material: platform order puts cancel first', (t) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actionOrder: GlassAlertActionOrder.platform,
          actions: const [_delete, _cancel],
        ),
      );
      expect(
        t.getCenter(find.text('Cancel')).dx,
        lessThan(t.getCenter(find.text('Delete')).dx),
      );
    }, variant: android);

    testWidgets('Material: given order by default', (t) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actions: const [_delete, _cancel],
        ),
      );
      expect(
        t.getCenter(find.text('Delete')).dx,
        lessThan(t.getCenter(find.text('Cancel')).dx),
      );
    }, variant: android);
  });

  group('W10 action subtitle', () {
    const share = GlassDialogAction(
      label: 'Share',
      subtitle: 'With your contacts',
    );

    testWidgets('glass alert: a secondary second line, in semantics', (
      t,
    ) async {
      shaderEnv();
      final s = t.ensureSemantics();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actions: const [share],
        ),
      );
      final label = t.getRect(find.text('Share'));
      final sub = t.getRect(find.text('With your contacts'));
      expect(sub.top, greaterThanOrEqualTo(label.bottom));
      final style = t.widget<Text>(find.text('With your contacts')).style!;
      expect(
        style.color,
        CupertinoColors.secondaryLabel.resolveFrom(
          t.element(find.text('With your contacts')),
        ),
      );
      expect(
        t.getSemantics(find.text('Share')),
        matchesSemantics(
          label: 'Share\nWith your contacts',
          isButton: true,
          hasTapAction: true,
        ),
      );
      s.dispose();
    }, variant: ios);

    testWidgets('glass action sheet: the second line', (t) async {
      shaderEnv();
      await _open(
        t,
        (context) =>
            showGlassActionSheet(context: context, actions: const [share]),
      );
      expect(find.text('With your contacts'), findsOneWidget);
      expect(
        t.getRect(find.text('With your contacts')).top,
        greaterThanOrEqualTo(t.getRect(find.text('Share')).bottom),
      );
    }, variant: ios);

    testWidgets('Material alert: the second line', (t) async {
      shaderEnv();
      await _open(
        t,
        (context) => showGlassAlert(
          context: context,
          title: 'Title',
          actions: const [share],
        ),
      );
      expect(find.text('With your contacts'), findsOneWidget);
      expect(
        t.getRect(find.text('With your contacts')).top,
        greaterThanOrEqualTo(t.getRect(find.text('Share')).bottom),
      );
    }, variant: android);

    testWidgets('Material action sheet: a ListTile subtitle', (t) async {
      shaderEnv();
      await _open(
        t,
        (context) =>
            showGlassActionSheet(context: context, actions: const [share]),
      );
      final tile = t.widget<ListTile>(
        find.ancestor(of: find.text('Share'), matching: find.byType(ListTile)),
      );
      expect((tile.subtitle! as Text).data, 'With your contacts');
    }, variant: android);
  });
}
