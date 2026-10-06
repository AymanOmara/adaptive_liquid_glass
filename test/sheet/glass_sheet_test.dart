import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _app(void Function(Object?) done) => MaterialApp(
  home: Builder(
    builder: (context) => Center(
      child: TextButton(
        onPressed: () async => done(
          await showGlassSheet<String>(
            context: context,
            builder: (context) => TextButton(
              onPressed: () => Navigator.pop(context, 'picked'),
              child: const Text('Pick'),
            ),
          ),
        ),
        child: const Text('Open'),
      ),
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('a glass sheet floats in from the edges and returns a value', (
    t,
  ) async {
    shaderEnv();
    Object? result;
    await t.pumpWidget(_app((r) => result = r));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final sheet = t.getRect(find.byType(GlassSheet));
    final glass = t.getRect(
      find.descendant(
        of: find.byType(GlassSheet),
        matching: find.byType(LiquidGlass),
      ),
    );
    expect(glass.left - sheet.left, 8);
    expect(sheet.bottom - glass.bottom, 8);
    expect(glass.bottom, moreOrLessEquals(600 - 8));
    await t.tap(find.text('Pick'));
    await t.pumpAndSettle();
    expect(result, 'picked');
    expect(find.byType(GlassSheet), findsNothing);
  }, variant: ios);

  testWidgets('tapping outside dismisses it', (t) async {
    shaderEnv();
    await t.pumpWidget(_app((_) {}));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tapAt(const Offset(400, 20));
    await t.pumpAndSettle();
    expect(find.byType(GlassSheet), findsNothing);
  }, variant: ios);

  testWidgets('Material: a Material 3 bottom sheet', (t) async {
    shaderEnv();
    await t.pumpWidget(_app((_) {}));
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(find.byType(GlassSheet), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Pick'), findsOneWidget);
  }, variant: android);
}
