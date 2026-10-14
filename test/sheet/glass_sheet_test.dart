import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/sheet/sheet_expansion.dart';
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

  testWidgets('cornerRadius and grabberSize change the floating sheet', (
    t,
  ) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGlassSheet<void>(
              context: context,
              cornerRadius: 20,
              grabberSize: const Size(36, 5),
              builder: (_) => const SizedBox(height: 100),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final glass = t.widget<LiquidGlass>(
      find.descendant(
        of: find.byType(GlassSheet),
        matching: find.byType(LiquidGlass),
      ),
    );
    expect(glass.shape, const GlassShape.rect(20));
    final grabber = find.descendant(
      of: find.byType(GlassSheet),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is ShapeDecoration &&
            (w.decoration! as ShapeDecoration).shape is StadiumBorder,
      ),
    );
    expect(t.getSize(grabber), const Size(36, 5));
  }, variant: ios);

  testWidgets('Material: cornerRadius rounds the bottom sheet', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGlassSheet<void>(
              context: context,
              cornerRadius: 20,
              builder: (_) => const SizedBox(height: 100),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(
      t.widget<BottomSheet>(find.byType(BottomSheet)).shape,
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }, variant: android);

  testWidgets('Material widgets work in a glass sheet (W18)', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showGlassSheet<void>(
              context: context,
              builder: (_) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(title: const Text('Row'), onTap: () {}),
                  const TextField(),
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Row'), findsOneWidget);
  }, variant: ios);

  for (final grabber in [true, false]) {
    testWidgets('contentHeight gives the content exactly that (W19), '
        'grabber $grabber', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showGlassSheet<void>(
                context: context,
                showGrabber: grabber,
                detents: const [GlassSheetDetent.contentHeight(200)],
                builder: (_) => const SizedBox.expand(key: Key('content')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(
        t.getSize(find.byKey(const Key('content'))).height,
        moreOrLessEquals(200),
      );
    }, variant: ios);
  }

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

  // SwiftUI's .height(_:) sheets (300...765 pt, measured 2026-10-14)
  // float 8 pt in from the sides; only the large detent runs edge to edge.
  for (final h in [300.0, 600.0, 700.0]) {
    testWidgets('a $h-pt detent floats 8 pt in from the sides', (t) async {
      shaderEnv();
      await openDetents(t, [GlassSheetDetent.height(h)]);
      final glass = t.getRect(
        find.descendant(
          of: find.byType(GlassSheet),
          matching: find.byType(LiquidGlass),
        ),
      );
      expect(glass.left, moreOrLessEquals(8));
      expect(glass.right, moreOrLessEquals(402 - 8));
    }, variant: ios);
  }

  test('sheetExpansion: floating at every partial stop, edge to edge at '
      'large', () {
    // Medium resolves to 459, large to 812 on an 874-pt screen.
    double e(double h, List<double> stops) =>
        sheetExpansion(h, stops, medium: 459, large: 812);
    expect(e(608, [608]), 0);
    expect(e(459, [459, 812]), 0);
    expect(e(812, [459, 812]), 1);
    expect(e(635.5, [459, 812]), moreOrLessEquals(0.5));
    // Between a 608-pt detent and large the sheet morphs from 608 up.
    expect(e(608, [608, 812]), 0);
    expect(e(710, [608, 812]), moreOrLessEquals(0.5));
    // A large-only sheet dragged down morphs back from medium.
    expect(e(635.5, [812]), moreOrLessEquals(0.5));
    // A detent within the measured gap of large is edge to edge.
    expect(e(800, [800]), 1);
  });

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
