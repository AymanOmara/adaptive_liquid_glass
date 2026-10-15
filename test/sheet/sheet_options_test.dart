import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// Opens a sheet on an iPhone 17 Pro sized view (402 x 874, status bar
/// 62) and returns the content's context once it is up.
Future<BuildContext> _open(
  WidgetTester t, {
  List<GlassSheetDetent> detents = const [],
  bool? isScrollControlled,
  bool enableDrag = true,
  bool isDismissible = true,
  double? maxHeightFactor,
  double contentHeight = 100,
}) async {
  t.view.physicalSize = const Size(402, 874);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 62, bottom: 34);
  addTearDown(t.view.reset);
  late BuildContext content;
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showGlassSheet<void>(
              context: context,
              detents: detents,
              isScrollControlled: isScrollControlled,
              enableDrag: enableDrag,
              isDismissible: isDismissible,
              maxHeightFactor: maxHeightFactor,
              builder: (context) {
                content = context;
                return SizedBox(
                  height: contentHeight,
                  child: const Text('Body'),
                );
              },
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('Open'));
  await t.pumpAndSettle();
  return content;
}

ModalBottomSheetRoute<void> _route(BuildContext content) =>
    ModalRoute.of(content)! as ModalBottomSheetRoute<void>;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  group('Material', () {
    testWidgets('defaults keep the derived scroll control and drag (W5, W6)', (
      t,
    ) async {
      shaderEnv();
      var route = _route(await _open(t));
      expect(route.isScrollControlled, isFalse);
      expect(route.enableDrag, isTrue);
      expect(route.constraints, isNull);
      Navigator.of(t.element(find.text('Body'))).pop();
      await t.pumpAndSettle();
      route = _route(
        await _open(
          t,
          detents: const [GlassSheetDetent.medium, GlassSheetDetent.large],
        ),
      );
      expect(route.isScrollControlled, isTrue);
    }, variant: android);

    testWidgets('isScrollControlled overrides the derivation (W5)', (t) async {
      shaderEnv();
      expect(
        _route(await _open(t, isScrollControlled: true)).isScrollControlled,
        isTrue,
      );
      Navigator.of(t.element(find.text('Body'))).pop();
      await t.pumpAndSettle();
      expect(
        _route(
          await _open(
            t,
            detents: const [GlassSheetDetent.large],
            isScrollControlled: false,
          ),
        ).isScrollControlled,
        isFalse,
      );
    }, variant: android);

    testWidgets('enableDrag false reaches the bottom sheet (W6)', (t) async {
      shaderEnv();
      final route = _route(await _open(t, enableDrag: false));
      expect(route.enableDrag, isFalse);
      expect(t.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag, false);
    }, variant: android);

    testWidgets('maxHeightFactor caps the whole bottom sheet (W19)', (t) async {
      shaderEnv();
      final route = _route(
        await _open(t, maxHeightFactor: 540 / 874, contentHeight: 2000),
      );
      expect(route.constraints?.maxHeight, moreOrLessEquals(540));
      expect(route.isScrollControlled, isTrue);
      expect(
        t.getSize(find.byType(BottomSheet)).height,
        lessThanOrEqualTo(540 + 1e-6),
      );
    }, variant: android);
  });

  group('glass', () {
    double sheetHeight(WidgetTester t) =>
        t.getSize(find.byType(GlassSheet)).height;

    testWidgets('maxHeightFactor caps the whole sized sheet, chrome included '
        '(W19)', (t) async {
      shaderEnv();
      await _open(t, maxHeightFactor: 540 / 874, contentHeight: 2000);
      expect(sheetHeight(t), lessThanOrEqualTo(540 + 1e-6));
      expect(sheetHeight(t), moreOrLessEquals(540));
      expect(t.takeException(), isNull);
    }, variant: ios);

    testWidgets('maxHeightFactor caps a detent (W19)', (t) async {
      shaderEnv();
      await _open(
        t,
        detents: const [GlassSheetDetent.large],
        maxHeightFactor: 540 / 874,
      );
      expect(sheetHeight(t), moreOrLessEquals(540));
      expect(t.getRect(find.byType(GlassSheet)).bottom, moreOrLessEquals(874));
    }, variant: ios);

    testWidgets('maxHeightFactor caps a contentHeight detent with its chrome '
        '(W19)', (t) async {
      shaderEnv();
      await _open(
        t,
        detents: const [GlassSheetDetent.contentHeight(540)],
        maxHeightFactor: 540 / 874,
      );
      expect(sheetHeight(t), lessThanOrEqualTo(540 + 1e-6));
    }, variant: ios);

    testWidgets('a sheet without the cap is unchanged', (t) async {
      shaderEnv();
      await _open(t, detents: const [GlassSheetDetent.contentHeight(540)]);
      expect(sheetHeight(t), moreOrLessEquals(540 + 4.67 + 5 + 8));
    }, variant: ios);

    testWidgets('enableDrag false: a fling does not dismiss, a tap outside '
        'does (W6)', (t) async {
      shaderEnv();
      await _open(t, enableDrag: false);
      final before = t.getRect(find.byType(GlassSheet));
      await t.fling(find.text('Body'), const Offset(0, 300), 1500);
      await t.pumpAndSettle();
      expect(t.getRect(find.byType(GlassSheet)), before);
      await t.tapAt(const Offset(200, 20));
      await t.pumpAndSettle();
      expect(find.byType(GlassSheet), findsNothing);
    }, variant: ios);

    testWidgets('enableDrag false: a drag does not move between detents (W6)', (
      t,
    ) async {
      shaderEnv();
      await _open(
        t,
        detents: const [GlassSheetDetent.medium, GlassSheetDetent.large],
        enableDrag: false,
      );
      final top = t.getRect(find.byType(GlassSheet)).top;
      await t.timedDrag(
        find.text('Body'),
        const Offset(0, -300),
        const Duration(milliseconds: 600),
      );
      await t.pumpAndSettle();
      expect(t.getRect(find.byType(GlassSheet)).top, top);
    }, variant: ios);

    testWidgets('isDismissible false with drag on: barrier tap stays (W6)', (
      t,
    ) async {
      shaderEnv();
      await _open(t, isDismissible: false);
      await t.tapAt(const Offset(200, 20));
      await t.pumpAndSettle();
      expect(find.byType(GlassSheet), findsOneWidget);
    }, variant: ios);
  });
}
