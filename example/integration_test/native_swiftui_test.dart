import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// The overhang the native layer adds around the group (kNativeOverhang).
const double overhang = 24;

/// Two members in a native group; the first is [first] points wide.
Widget scene(double first, {bool dark = false}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(402, 874),
    platformBrightness: dark ? Brightness.dark : Brightness.light,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      children: [
        Positioned(
          left: 40,
          top: 300,
          child: GlassGroup(
            spacing: 12,
            mode: GlassRenderMode.native,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LiquidGlass(child: SizedBox(width: first, height: 50)),
                const SizedBox(width: 8),
                const LiquidGlass(
                  shape: GlassShape.rect(16),
                  child: SizedBox(width: 60, height: 50),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);

/// Asks the platform view what SwiftUI is drawing.
Future<Map<Object?, Object?>> state(MethodChannel channel) async =>
    (await channel.invokeMapMethod<Object?, Object?>('debugState'))!;

/// Lets platform messages complete in real time, then pumps.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

List<double> rect(Object? r) => [
  for (final v in r! as List<Object?>) (v! as num).toDouble(),
];

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Must run first: the package has not read the platform channel yet, so
  // this is what an app sees on its very first glass frame.
  testWidgets('iOS 26+ is native from the first frame, with no flag', (
    tester,
  ) async {
    bool isBackdrop(Widget w) => w.runtimeType.toString() == 'GlassBackdrop';
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: LiquidGlass(child: SizedBox(width: 120, height: 50)),
        ),
      ),
    );
    // The first frame already hosts the platform view: no shader frame
    // before the environment channel answers.
    expect(find.byType(UiKitView), findsOneWidget);
    expect(find.byWidgetPredicate(isBackdrop), findsNothing);
    for (var i = 0; i < 10; i++) {
      await settle(tester);
      expect(find.byType(UiKitView), findsOneWidget);
      expect(find.byWidgetPredicate(isBackdrop), findsNothing);
    }
  });

  testWidgets('a brightness flip rebuilds the glass and settles again', (
    tester,
  ) async {
    await tester.pumpWidget(scene(120));
    await settle(tester);
    final id = tester.allRenderObjects
        .whereType<RenderUiKitView>()
        .single
        .viewController
        .id;
    final channel = MethodChannel('adaptive_liquid_glass/native_glass_$id');

    var s = await state(channel);
    expect(s['visible'], true);
    expect(s['dark'], false);
    expect(s['style'], 'light');
    expect(s['generation'], 0);
    expect(s['settled'], 1);

    // Geometry alone never rebuilds the glass.
    await tester.pumpWidget(scene(140));
    await settle(tester);
    s = await state(channel);
    expect(s['generation'], 0);
    expect(s['settled'], 1);

    // Light to dark: a new container generation, hidden, then drawn again
    // after the settle frames, with the UIKit style following.
    await tester.pumpWidget(scene(140, dark: true));
    await settle(tester);
    s = await state(channel);
    expect(s['dark'], true);
    expect(s['style'], 'dark');
    expect(s['generation'], 1);
    expect(s['settled'], 2);
    expect(s['visible'], true);

    // And back.
    await tester.pumpWidget(scene(140));
    await settle(tester);
    s = await state(channel);
    expect(s['dark'], false);
    expect(s['style'], 'light');
    expect(s['generation'], 2);
    expect(s['settled'], 3);
    expect(s['visible'], true);
  });

  testWidgets('native glass hosts SwiftUI, follows setShapes, disposes', (
    tester,
  ) async {
    await tester.pumpWidget(scene(120));
    await settle(tester);

    // Created: one platform view.
    final view = find.byType(UiKitView);
    expect(view, findsOneWidget);
    final id = tester.allRenderObjects
        .whereType<RenderUiKitView>()
        .single
        .viewController
        .id;
    final channel = MethodChannel('adaptive_liquid_glass/native_glass_$id');

    var s = await state(channel);
    expect(s['hosted'], true);
    // Drawn once on screen for a few frames (GlassRootView.settleFrames).
    expect(s['visible'], true);
    expect(s['interactive'], false);
    expect(s['clearBackground'], true);
    // The hosting view fills the platform view, with no safe area.
    final bounds = rect(s['bounds']);
    expect(bounds, [188 + 2 * overhang, 50 + 2 * overhang]);
    expect(rect(s['hostFrame']), [0, 0, ...bounds]);
    expect(rect(s['safeArea']), [0, 0, 0, 0]);
    expect(s['spacing'], 12.0);
    expect(s['dark'], false);
    var shapes = [for (final r in s['shapes']! as List<Object?>) rect(r)];
    expect(shapes, [
      [overhang, overhang, 120, 50],
      [overhang + 128, overhang, 60, 50],
    ]);

    // setShapes: the first member grows and the group turns dark.
    await tester.pumpWidget(scene(150, dark: true));
    await settle(tester);
    expect(find.byType(UiKitView), findsOneWidget);
    s = await state(channel);
    expect(s['dark'], true);
    shapes = [for (final r in s['shapes']! as List<Object?>) rect(r)];
    expect(shapes, [
      [overhang, overhang, 150, 50],
      [overhang + 158, overhang, 60, 50],
    ]);
    expect(rect(s['bounds']), [218 + 2 * overhang, 50 + 2 * overhang]);

    // Stable ids from Dart, not payload indices; contained in the Flutter
    // view controller; UIKit style follows the app's brightness.
    expect(s['ids'], hasLength(2));
    expect((s['ids']! as List).toSet(), hasLength(2));
    expect(s['contained'], true);
    expect(s['style'], 'dark');

    // Dispose: the view is released and its channel handler cleared.
    await tester.pumpWidget(const SizedBox());
    Object? error;
    for (var i = 0; i < 10 && error == null; i++) {
      await settle(tester);
      try {
        await state(channel);
      } on MissingPluginException catch (e) {
        error = e;
      }
    }
    expect(error, isA<MissingPluginException>());
  });
}
