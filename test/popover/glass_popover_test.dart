import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(Alignment at, {double inset = 60}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: at,
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGlassPopover<void>(
              context: context,
              builder: (_) => const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Popover'),
              ),
            ),
            child: const Text('Anchor'),
          ),
        ),
      ),
    ),
  ),
);

Rect _bubble(WidgetTester t) => t.getRect(
  find.ancestor(of: find.text('Popover'), matching: find.byType(LiquidGlass)),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('opens over its anchor, centred, 10 below its top', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(Alignment.topCenter));
    final anchor = t.getRect(find.byType(TextButton));
    await t.tap(find.text('Anchor'));
    await t.pumpAndSettle();
    final bubble = _bubble(t);
    expect(bubble.top, moreOrLessEquals(anchor.top + 10));
    expect(bubble.center.dx, moreOrLessEquals(anchor.center.dx));
    await t.tapAt(const Offset(5, 590));
    await t.pumpAndSettle();
    expect(find.text('Popover'), findsNothing);
  }, variant: ios);

  testWidgets('near an edge it stays 10 inside the screen', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(Alignment.topRight));
    await t.tap(find.text('Anchor'));
    await t.pumpAndSettle();
    expect(_bubble(t).right, lessThanOrEqualTo(800 - 10));
  }, variant: ios);

  testWidgets('near the bottom it opens upwards', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(Alignment.bottomCenter, inset: 2));
    final anchor = t.getRect(find.byType(TextButton));
    await t.tap(find.text('Anchor'));
    await t.pumpAndSettle();
    expect(_bubble(t).bottom, moreOrLessEquals(anchor.bottom - 10));
  }, variant: ios);

  testWidgets('plain text in a popover is iOS body text, not the fallback', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(_app(Alignment.topCenter));
    await t.tap(find.text('Anchor'));
    await t.pumpAndSettle();
    final style = DefaultTextStyle.of(t.element(find.text('Popover'))).style;
    expect(style.fontSize, 17);
    expect(style.decoration, isNot(TextDecoration.underline));
    expect(style.letterSpacing, -0.43);
  }, variant: ios);

  testWidgets('GlassPopoverAnchor: the opener steps aside while open', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Center(
          child: GlassPopoverAnchor(
            popoverBuilder: (_) => const Text('Popover'),
            builder: (context, open) =>
                TextButton(onPressed: open, child: const Text('Anchor')),
          ),
        ),
      ),
    );
    await t.tap(find.text('Anchor'));
    await t.pumpAndSettle();
    expect(find.text('Anchor'), findsNothing);
    expect(find.text('Popover'), findsOneWidget);
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
    expect(find.text('Anchor'), findsOneWidget);
  }, variant: ios);
}
