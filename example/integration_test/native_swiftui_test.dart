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
