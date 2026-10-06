import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(Alignment at) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: at,
      child: Padding(
        padding: const EdgeInsets.all(60),
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

  testWidgets('opens over its anchor, centred, 21 below its top', (t) async {
    shaderEnv();
    await t.pumpWidget(_app(Alignment.topCenter));
    final anchor = t.getRect(find.byType(TextButton));
    await t.tap(find.text('Anchor'));
    await t.pumpAndSettle();
    final bubble = _bubble(t);
    expect(bubble.top, moreOrLessEquals(anchor.top + 21));
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
    await t.pumpWidget(_app(Alignment.bottomCenter));
    final anchor = t.getRect(find.byType(TextButton));
    await t.tap(find.text('Anchor'));
    await t.pumpAndSettle();
    expect(_bubble(t).bottom, moreOrLessEquals(anchor.bottom - 21));
  }, variant: ios);
}
