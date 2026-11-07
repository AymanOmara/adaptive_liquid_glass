import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/toolbar/keyboard_toolbar_metrics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

const _keyboard = 336.0;

Widget _button(String label, [List<String>? taps]) => GlassButton.icon(
  onPressed: () => taps?.add(label),
  icon: CupertinoIcons.circle,
  semanticLabel: label,
);

Widget _host({
  List<String>? taps,
  TextDirection dir = TextDirection.ltr,
  bool resize = true,
}) => MaterialApp(
  builder: (c, child) => Directionality(textDirection: dir, child: child!),
  home: Scaffold(
    resizeToAvoidBottomInset: resize,
    body: Column(
      children: [
        GlassKeyboardToolbar(
          children: [
            _button('Up', taps),
            _button('Down', taps),
            const GlassToolbarSpacer(),
            _button('Done', taps),
          ],
          child: const TextField(key: Key('inside')),
        ),
        const TextField(key: Key('outside')),
      ],
    ),
  ),
);

/// A 402 x 874 phone; [keyboard] raises the software keyboard.
void _phone(WidgetTester t, {double keyboard = 0}) {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 62, bottom: 34);
  t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
}

Future<void> _focus(WidgetTester t, String key) async {
  await t.tap(find.byKey(Key(key)));
  _phone(t, keyboard: _keyboard);
  await t.pumpAndSettle();
}

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('hidden until a field inside it has focus', (t) async {
    shaderEnv();
    _phone(t);
    await t.pumpWidget(_host());
    expect(find.bySemanticsLabel('Done'), findsNothing);
    await _focus(t, 'outside');
    expect(find.bySemanticsLabel('Done'), findsNothing);
  }, variant: ios);

  testWidgets('floats above the keyboard while a field inside has focus', (
    t,
  ) async {
    shaderEnv();
    _phone(t);
    await t.pumpWidget(_host());
    await _focus(t, 'inside');
    final done = t.getRect(find.bySemanticsLabel('Done'));
    expect(
      done.bottom,
      moreOrLessEquals(
        874 - _keyboard - KeyboardToolbarMetrics.gap,
        epsilon: 1,
      ),
    );
    // A spacer pushes Done to the trailing end.
    expect(done.right, greaterThan(402 - KeyboardToolbarMetrics.edgeInset - 2));
    expect(
      t.getRect(find.bySemanticsLabel('Up')).left,
      lessThan(KeyboardToolbarMetrics.edgeInset + 2),
    );
  }, variant: ios);

  testWidgets('the same place when the Scaffold does not resize', (t) async {
    shaderEnv();
    _phone(t);
    await t.pumpWidget(_host(resize: false));
    await _focus(t, 'inside');
    expect(
      t.getRect(find.bySemanticsLabel('Done')).bottom,
      moreOrLessEquals(
        874 - _keyboard - KeyboardToolbarMetrics.gap,
        epsilon: 1,
      ),
    );
  }, variant: ios);

  testWidgets('its buttons work and focus moving out hides it', (t) async {
    shaderEnv();
    final taps = <String>[];
    _phone(t);
    await t.pumpWidget(_host(taps: taps));
    await _focus(t, 'inside');
    await t.tap(find.bySemanticsLabel('Down'));
    expect(taps, ['Down']);
    await t.tap(find.byKey(const Key('outside')));
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Done'), findsNothing);
  }, variant: ios);

  testWidgets('hidden while the keyboard is down', (t) async {
    shaderEnv();
    _phone(t);
    await t.pumpWidget(_host());
    await _focus(t, 'inside');
    _phone(t);
    await t.pumpAndSettle();
    expect(find.bySemanticsLabel('Done'), findsNothing);
  }, variant: ios);

  testWidgets('right to left mirrors the groups', (t) async {
    shaderEnv();
    _phone(t);
    await t.pumpWidget(_host(dir: TextDirection.rtl));
    await _focus(t, 'inside');
    expect(
      t.getRect(find.bySemanticsLabel('Done')).left,
      lessThan(t.getRect(find.bySemanticsLabel('Up')).left),
    );
  }, variant: ios);

  testWidgets('Reduce Motion shows it at once', (t) async {
    shaderEnv();
    _phone(t);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _host(),
      ),
    );
    await t.tap(find.byKey(const Key('inside')));
    _phone(t, keyboard: _keyboard);
    await t.pump();
    await t.pump();
    final fade = t.widget<FadeTransition>(
      find
          .ancestor(
            of: find.bySemanticsLabel('Done'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1);
  }, variant: ios);

  testWidgets('Material path: a full-width bar on the keyboard', (t) async {
    shaderEnv();
    _phone(t);
    await t.pumpWidget(_host());
    await _focus(t, 'inside');
    final bar = t.getRect(find.byKey(KeyboardToolbarMetrics.materialBarKey));
    expect(bar.left, 0);
    expect(bar.right, 402);
    expect(bar.bottom, moreOrLessEquals(874 - _keyboard, epsilon: 1));
    expect(find.bySemanticsLabel('Done'), findsOneWidget);
  }, variant: android);
}
