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

  Future<void> openDetents(
    WidgetTester t,
    List<GlassSheetDetent> detents, {
    int initial = 0,
  }) async {
    t.view.physicalSize = const Size(402, 874);
    t.view.devicePixelRatio = 1;
    t.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showGlassSheet<void>(
                context: context,
                detents: detents,
                initialDetent: initial,
                builder: (_) => const Text('Body'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
  }

  Rect sheetRect(WidgetTester t) => t.getRect(find.byType(GlassSheet));

  testWidgets('medium: floating glass, its top at the measured height', (
    t,
  ) async {
    shaderEnv();
    await openDetents(t, const [GlassSheetDetent.medium]);
    final sheet = sheetRect(t);
    expect(sheet.top, moreOrLessEquals(874 - 459, epsilon: 0.5));
    expect(sheet.bottom, moreOrLessEquals(874));
    expect(
      find.descendant(
        of: find.byType(GlassSheet),
        matching: find.byType(LiquidGlass),
      ),
      findsOneWidget,
    );
  }, variant: ios);

  testWidgets('large: edge to edge from the status bar, opaque', (t) async {
    shaderEnv();
    await openDetents(t, const [GlassSheetDetent.large]);
    final sheet = sheetRect(t);
    expect(sheet.top, moreOrLessEquals(62));
    expect(sheet.left, 0);
    expect(sheet.width, 402);
    // The opaque surface has replaced the glass.
    expect(
      find.descendant(
        of: find.byType(GlassSheet),
        matching: find.byType(LiquidGlass),
      ),
      findsNothing,
    );
  }, variant: ios);

  testWidgets('dragging up moves a medium sheet to large', (t) async {
    shaderEnv();
    await openDetents(t, const [
      GlassSheetDetent.medium,
      GlassSheetDetent.large,
    ]);
    await t.timedDrag(
      find.text('Body'),
      const Offset(0, -300),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(sheetRect(t).top, moreOrLessEquals(62));
  }, variant: ios);

  testWidgets('a fling down from the lowest detent dismisses', (t) async {
    shaderEnv();
    await openDetents(t, const [GlassSheetDetent.medium]);
    await t.fling(find.text('Body'), const Offset(0, 300), 1500);
    await t.pumpAndSettle();
    expect(find.byType(GlassSheet), findsNothing);
  }, variant: ios);

  testWidgets('a short drag down settles back on the detent', (t) async {
    shaderEnv();
    await openDetents(t, const [GlassSheetDetent.medium]);
    await t.timedDrag(
      find.text('Body'),
      const Offset(0, 40),
      const Duration(milliseconds: 600),
    );
    await t.pumpAndSettle();
    expect(find.byType(GlassSheet), findsOneWidget);
    expect(sheetRect(t).top, moreOrLessEquals(874 - 459, epsilon: 0.5));
  }, variant: ios);
}
