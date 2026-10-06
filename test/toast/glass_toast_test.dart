import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/semantics.dart' show SemanticsFlag;
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

late BuildContext _toastContext;

Widget _messengerApp() => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) {
        _toastContext = context;
        return const SizedBox();
      },
    ),
  ),
);

Widget _reducedMotionApp() => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) {
        _toastContext = context;
        return const SizedBox();
      },
    ),
  ),
);

Widget _rtlApp() => MaterialApp(
  builder: (context, child) =>
      Directionality(textDirection: TextDirection.rtl, child: child!),
  home: Scaffold(
    body: Builder(
      builder: (context) {
        _toastContext = context;
        return const SizedBox();
      },
    ),
  ),
);

Widget _plainApp() => MediaQuery(
  data: MediaQueryData.fromView(
    WidgetsBinding.instance.platformDispatcher.implicitView!,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) {
            _toastContext = context;
            return const SizedBox();
          },
        ),
      ],
    ),
  ),
);

bool _coversLabel(SemanticsNode node, String label) {
  if (node.getSemanticsData().label.contains(label)) return true;
  var found = false;
  node.visitChildren((child) {
    found = found || _coversLabel(child, label);
    return !found;
  });
  return found;
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a glass capsule that settles on screen, then leaves', (t) async {
    shaderEnv();
    await t.pumpWidget(_messengerApp());
    final handle = showGlassToast(_toastContext, message: 'Saved');
    await t.pump();
    expect(find.byType(LiquidGlass), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    await t.pumpAndSettle();
    expect(t.getRect(find.byType(LiquidGlass)).top, greaterThanOrEqualTo(0));
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(handle.closed, completes);
    await handle.closed;
  }, variant: ios);

  testWidgets('the glass is at least minHeight tall', (t) async {
    shaderEnv();
    await t.pumpWidget(_messengerApp());
    showGlassToast(_toastContext, message: 'Saved');
    await t.pumpAndSettle();
    expect(
      t.getRect(find.byType(LiquidGlass)).height,
      greaterThanOrEqualTo(48),
    );
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  }, variant: ios);

  testWidgets('one toast at a time; the second waits its turn', (t) async {
    shaderEnv();
    await t.pumpWidget(_messengerApp());
    final first = showGlassToast(_toastContext, message: 'One');
    final second = showGlassToast(_toastContext, message: 'Two');
    await t.pump();
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsNothing);
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Two'), findsNothing);
    await first.closed;
    await second.closed;
  }, variant: ios);

  testWidgets('dismiss closes the shown toast', (t) async {
    shaderEnv();
    await t.pumpWidget(_messengerApp());
    final handle = showGlassToast(_toastContext, message: 'Saved');
    await t.pumpAndSettle();
    handle.dismiss();
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    await handle.closed;
  }, variant: ios);

  testWidgets('dismissing a waiting toast removes it from the queue', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_messengerApp());
    final first = showGlassToast(_toastContext, message: 'One');
    final second = showGlassToast(_toastContext, message: 'Two');
    await t.pump();
    second.dismiss();
    await second.closed;
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Two'), findsNothing);
    expect(find.text('One'), findsNothing);
    await first.closed;
  }, variant: ios);

  testWidgets('a swipe up dismisses; a small downward drag does not', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_messengerApp());
    showGlassToast(_toastContext, message: 'Saved');
    await t.pumpAndSettle();
    await t.drag(find.text('Saved'), const Offset(0, -100));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);

    showGlassToast(_toastContext, message: 'Kept');
    await t.pumpAndSettle();
    await t.drag(find.text('Kept'), const Offset(0, 15));
    await t.pumpAndSettle();
    expect(find.text('Kept'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Kept'), findsNothing);
  }, variant: ios);

  testWidgets('tapping the action calls back and dismisses', (t) async {
    shaderEnv();
    await t.pumpWidget(_messengerApp());
    var pressed = 0;
    final handle = showGlassToast(
      _toastContext,
      message: 'Moved',
      action: GlassToastAction(label: 'Undo', onPressed: () => pressed++),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Undo'));
    await t.pump();
    expect(pressed, 1);
    await t.pumpAndSettle();
    expect(find.text('Moved'), findsNothing);
    await handle.closed;
  }, variant: ios);

  testWidgets('duration: null stays until dismissed', (t) async {
    shaderEnv();
    await t.pumpWidget(_messengerApp());
    final handle = showGlassToast(
      _toastContext,
      message: 'Saved',
      duration: null,
    );
    await t.pump();
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    handle.dismiss();
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    await handle.closed;
  }, variant: ios);

  testWidgets('Reduce Motion fades in place, never translating', (t) async {
    shaderEnv();
    await t.pumpWidget(_reducedMotionApp());
    showGlassToast(_toastContext, message: 'Saved');
    await t.pump();
    expect(
      find.ancestor(of: find.text('Saved'), matching: find.byType(Opacity)),
      findsOneWidget,
    );
    final top = t.getRect(find.text('Saved')).top;
    await t.pump(const Duration(milliseconds: 100));
    expect(t.getRect(find.text('Saved')).top, moreOrLessEquals(top));
    await t.pumpAndSettle();
    expect(t.getRect(find.text('Saved')).top, moreOrLessEquals(top));
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  }, variant: ios);

  testWidgets('announced as a live region', (t) async {
    shaderEnv();
    final semantics = t.ensureSemantics();
    await t.pumpWidget(_messengerApp());
    final handle = showGlassToast(
      _toastContext,
      message: 'Saved',
      duration: null,
    );
    await t.pumpAndSettle();
    final live = find.semantics.byFlag(SemanticsFlag.isLiveRegion);
    expect(live, findsWidgets);
    var covers = false;
    for (final node in live.evaluate()) {
      if (_coversLabel(node, 'Saved')) covers = true;
    }
    expect(covers, isTrue);
    handle.dismiss();
    await t.pumpAndSettle();
    semantics.dispose();
  }, variant: ios);

  testWidgets('RTL: the icon leads on the right', (t) async {
    shaderEnv();
    await t.pumpWidget(_rtlApp());
    showGlassToast(
      _toastContext,
      message: 'Saved',
      icon: CupertinoIcons.checkmark,
    );
    await t.pumpAndSettle();
    expect(
      t.getRect(find.byIcon(CupertinoIcons.checkmark)).left,
      greaterThan(t.getRect(find.text('Saved')).right),
    );
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  }, variant: ios);

  testWidgets('Material: a SnackBar through the messenger', (t) async {
    shaderEnv();
    await t.pumpWidget(_messengerApp());
    final handle = showGlassToast(_toastContext, message: 'Saved');
    await t.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    handle.dismiss();
    await t.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await handle.closed;
  }, variant: android);

  testWidgets('Material without a messenger: a bottom surface that '
      'auto-dismisses', (t) async {
    shaderEnv();
    await t.pumpWidget(_plainApp());
    final handle = showGlassToast(_toastContext, message: 'Saved');
    await t.pump();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(Material), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    await t.pumpAndSettle();
    expect(t.getRect(find.byType(Material)).bottom, greaterThan(400));
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    await handle.closed;
  }, variant: android);
}
