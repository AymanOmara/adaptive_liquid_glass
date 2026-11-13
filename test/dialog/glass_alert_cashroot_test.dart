// CashRoot feedback: W34 (root navigator), W35 (long message scrolls),
// W9 (messageSpan, action tint).
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/dialog/glass_dialog_card.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

final _nestedKey = GlobalKey<NavigatorState>();

/// A page with a nested navigator (as a go_router shell branch) holding
/// the Open button, under a bar drawn by the root page.
Widget _nestedApp(Future<void> Function(BuildContext) open) => MaterialApp(
  home: Column(
    children: [
      Expanded(
        child: Navigator(
          key: _nestedKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => open(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 50, child: Text('Tab bar')),
    ],
  ),
);

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

Future<void> _open(WidgetTester t, Widget app) async {
  await t.pumpWidget(app);
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
}

bool _onRoot(WidgetTester t, Finder f) {
  final nav = t.state<NavigatorState>(
    find.ancestor(of: f, matching: find.byType(Navigator)).first,
  );
  return nav != _nestedKey.currentState;
}

const _ok = GlassDialogAction(label: 'OK');
const _cancel = GlassDialogAction(
  label: 'Cancel',
  role: GlassButtonRole.cancel,
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('W34 useRootNavigator', () {
    testWidgets('glass alert: root navigator by default', (t) async {
      shaderEnv();
      await _open(
        t,
        _nestedApp(
          (c) => showGlassAlert(context: c, title: 'T', actions: const [_ok]),
        ),
      );
      expect(_onRoot(t, find.byType(GlassDialogCard)), isTrue);
    }, variant: ios);

    testWidgets('glass alert: false keeps the nearest navigator', (t) async {
      shaderEnv();
      await _open(
        t,
        _nestedApp(
          (c) => showGlassAlert(
            context: c,
            title: 'T',
            actions: const [_ok],
            useRootNavigator: false,
          ),
        ),
      );
      expect(_onRoot(t, find.byType(GlassDialogCard)), isFalse);
    }, variant: ios);

    testWidgets('glass confirmation dialog: root navigator by default', (
      t,
    ) async {
      shaderEnv();
      await _open(
        t,
        _nestedApp(
          (c) => showGlassConfirmationDialog(
            context: c,
            title: 'T',
            actions: const [_ok, _cancel],
          ),
        ),
      );
      expect(_onRoot(t, find.byType(GlassDialogCard)), isTrue);
    }, variant: ios);

    testWidgets('glass confirmation dialog: false keeps the nearest', (
      t,
    ) async {
      shaderEnv();
      await _open(
        t,
        _nestedApp(
          (c) => showGlassConfirmationDialog(
            context: c,
            title: 'T',
            actions: const [_ok, _cancel],
            useRootNavigator: false,
          ),
        ),
      );
      expect(_onRoot(t, find.byType(GlassDialogCard)), isFalse);
    }, variant: ios);

    testWidgets('Material alert: false keeps the nearest navigator', (t) async {
      await _open(
        t,
        _nestedApp(
          (c) => showGlassAlert(
            context: c,
            title: 'T',
            actions: const [_ok],
            useRootNavigator: false,
          ),
        ),
      );
      expect(_onRoot(t, find.byType(AlertDialog)), isFalse);
    }, variant: android);
  });

  group('W35 long message', () {
    final long = List.filled(40, 'A long consent sentence.').join(' ');

    testWidgets('glass: scrolls at text scale 1 and keeps the buttons on '
        'screen in iPhone landscape', (t) async {
      shaderEnv();
      t.view.physicalSize = const Size(874, 402);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await _open(
        t,
        _app(
          (c) => showGlassAlert(
            context: c,
            title: 'Cloud consent',
            message: long,
            actions: const [
              _cancel,
              GlassDialogAction(label: 'Allow'),
            ],
          ),
        ),
      );
      expect(t.takeException(), isNull);
      final allow = t.getRect(find.text('Allow'));
      expect(allow.bottom, lessThanOrEqualTo(402));
      expect(allow.top, greaterThanOrEqualTo(0));
      // The text scrolls, the buttons do not.
      final scrollable = find.ancestor(
        of: find.text(long),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Allow'),
          matching: find.byType(Scrollable),
        ),
        findsNothing,
      );
      final textTop = t.getRect(find.text(long)).top;
      await t.drag(scrollable, const Offset(0, -200));
      await t.pumpAndSettle();
      expect(t.getRect(find.text(long)).top, lessThan(textTop));
      expect(t.getRect(find.text('Allow')), allow);
      await t.tap(find.text('Allow'));
      await t.pumpAndSettle();
      expect(find.byType(GlassDialogCard), findsNothing);
    }, variant: ios);

    testWidgets('glass: a short message keeps its height', (t) async {
      shaderEnv();
      await _open(
        t,
        _app(
          (c) => showGlassAlert(
            context: c,
            title: 'Title',
            message: 'Short',
            actions: const [_ok],
          ),
        ),
      );
      final message = t.getRect(find.text('Short'));
      final ok = t.getRect(find.text('OK'));
      final card = t.getRect(find.byType(GlassDialogCard));
      expect(message.bottom, lessThan(ok.top));
      expect(card.height, lessThan(300));
    }, variant: ios);
  });

  group('W9 messageSpan', () {
    testWidgets('glass: takes the message style and spacing', (t) async {
      shaderEnv();
      await _open(
        t,
        _app(
          (c) => showGlassAlert(
            context: c,
            title: 'Title',
            message: 'Plain',
            actions: const [_ok],
          ),
        ),
      );
      final plain = t.getRect(find.text('Plain'));
      final plainOk = t.getRect(find.text('OK'));
      final plainStyle = t
          .widget<RichText>(
            find.descendant(
              of: find.text('Plain'),
              matching: find.byType(RichText),
            ),
          )
          .text
          .style!;
      Navigator.of(t.element(find.text('OK'))).pop();
      await t.pumpAndSettle();

      await _open(
        t,
        _app(
          (c) => showGlassAlert(
            context: c,
            title: 'Title',
            messageSpan: const TextSpan(
              children: [
                TextSpan(text: 'Rich '),
                TextSpan(
                  text: 'bold',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            actions: const [_ok],
          ),
        ),
      );
      final finder = find.text('Rich bold', findRichText: true);
      expect(finder, findsOneWidget);
      final rich = t.getRect(finder);
      expect(rich.top, plain.top);
      // Same 20 pt gap from the message's last line to the buttons.
      expect(
        t.getRect(find.text('OK')).top - rich.bottom,
        plainOk.top - plain.bottom,
      );
      final style = t.widget<RichText>(finder).text.style!;
      expect(style.fontSize, plainStyle.fontSize);
      expect(style.color, plainStyle.color);
      expect(style.height, plainStyle.height);
    }, variant: ios);

    testWidgets('Material: a rich message', (t) async {
      await _open(
        t,
        _app(
          (c) => showGlassAlert(
            context: c,
            title: 'Title',
            messageSpan: const TextSpan(text: 'Rich text'),
            actions: const [_ok],
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Rich text', findRichText: true),
        ),
        findsOneWidget,
      );
    }, variant: android);
  });

  group('W9 action tint', () {
    const tint = Color(0xFF34C759);
    const tinted = GlassDialogAction(label: 'Save', tint: tint);

    Color? colourOf(WidgetTester t, String label) => t
        .widget<RichText>(
          find.descendant(
            of: find.text(label),
            matching: find.byType(RichText),
          ),
        )
        .text
        .style
        ?.color;

    testWidgets('glass: the label takes the tint', (t) async {
      shaderEnv();
      await _open(
        t,
        _app(
          (c) => showGlassAlert(
            context: c,
            title: 'T',
            actions: const [_cancel, tinted],
          ),
        ),
      );
      expect(colourOf(t, 'Save'), tint);
      expect(colourOf(t, 'Cancel'), isNot(tint));
    }, variant: ios);

    testWidgets('Material: the TextButton foreground takes the tint', (
      t,
    ) async {
      await _open(
        t,
        _app(
          (c) => showGlassAlert(
            context: c,
            title: 'T',
            actions: const [_cancel, tinted],
          ),
        ),
      );
      final button = t.widget<TextButton>(
        find.ancestor(of: find.text('Save'), matching: find.byType(TextButton)),
      );
      expect(button.style?.foregroundColor?.resolve({}), tint);
    }, variant: android);
  });
}
