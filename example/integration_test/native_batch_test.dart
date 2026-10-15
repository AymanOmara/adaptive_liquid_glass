import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 29 bare chips, as CashRoot's filter sheet: one native view each, or one
/// for all of them in a [GlassBatch]. Prints the view count and the time
/// until every view has drawn its glass (iOS 26+ simulator or device).
Widget scene({required bool batch}) {
  final chips = Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < 29; i++)
        GlassChip(label: 'Tag $i', onSelected: (_) {}),
    ],
  );
  return MediaQuery(
    data: const MediaQueryData(size: Size(402, 874)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: batch ? GlassBatch(child: chips) : chips,
        ),
      ),
    ),
  );
}

Future<Map<Object?, Object?>?> debugState(int id) async {
  try {
    return await MethodChannel('adaptive_liquid_glass/native_glass_$id')
        .invokeMapMethod<Object?, Object?>('debugState');
  } on MissingPluginException {
    return null;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> measure(WidgetTester tester, {required bool batch}) async {
    await tester.pumpWidget(const SizedBox());
    final first = platformViewsRegistry.getNextPlatformViewId() + 1;
    final watch = Stopwatch()..start();
    await tester.pumpWidget(scene(batch: batch));
    var ready = <Map<Object?, Object?>>[];
    while (watch.elapsed < const Duration(seconds: 30)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      final n = find.byType(UiKitView).evaluate().length;
      final states = [
        for (var id = first; id < first + n; id++) await debugState(id),
      ];
      if (n > 0 && states.every((s) => s != null && s['visible'] == true)) {
        ready = states.cast<Map<Object?, Object?>>();
        break;
      }
    }
    watch.stop();
    final shapes = ready.fold<int>(
      0,
      (sum, s) => sum + (s['shapes']! as List<Object?>).length,
    );
    // ignore: avoid_print
    print(
      'BATCH batch=$batch views=${find.byType(UiKitView).evaluate().length} '
      'shapes=$shapes visibleAfter=${watch.elapsedMilliseconds}ms',
    );
    expect(shapes, 29);
    expect(find.byType(UiKitView), batch ? findsOneWidget : findsNWidgets(29));
  }

  // Each order twice, so the first run's warm-up does not favour either.
  for (final batch in [true, false, true, false]) {
    testWidgets('29 chips${batch ? ' in a GlassBatch' : ', one view each'}', (
      tester,
    ) async {
      await measure(tester, batch: batch);
    });
  }
}
