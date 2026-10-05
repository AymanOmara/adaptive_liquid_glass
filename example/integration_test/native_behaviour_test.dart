import 'package:adaptive_liquid_glass_example/gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Lets platform messages complete in real time, then pumps.
Future<void> settle(WidgetTester tester, [int rounds = 5]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// What every live native view is drawing, by view id.
Future<Map<int, Map<Object?, Object?>>> states(WidgetTester tester) async {
  final out = <int, Map<Object?, Object?>>{};
  for (final r in tester.allRenderObjects.whereType<RenderUiKitView>()) {
    final id = r.viewController.id;
    final channel = MethodChannel('adaptive_liquid_glass/native_glass_$id');
    final s = await tester.runAsync(
      () => channel.invokeMapMethod<Object?, Object?>('debugState'),
    );
    out[id] = s!;
  }
  return out;
}

int shapeCount(Map<Object?, Object?> s) => (s['shapes']! as List).length;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The README cookbook (example Gallery) on iOS 26+, native by default:
  // buttons, padding, morphing, union, clear, tint and scrolling.
  testWidgets('gallery recipes work with native glass', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Gallery()));
    await settle(tester);
    // One native view per group (each standalone glass has its own).
    expect(find.byType(UiKitView), findsWidgets);
    expect(find.byType(BackdropFilter), findsNothing);

    // Union: the three tools share one union index.
    final union = (await states(tester)).values
        .firstWhere((s) => shapeCount(s) == 3);
    expect(union['unions'], [0, 0, 0]);

    // Hit testing through the glass: the button's snack bar shows.
    await tester.tap(find.text('Continue'));
    await settle(tester);
    expect(find.text('Pressed'), findsOneWidget);

    // Morphing by glassId: the toggle adds a second member to its group.
    Future<int> morphShapes() async => shapeCount(
      (await states(tester)).values.firstWhere(
        (s) => (s['shapes']! as List).isNotEmpty && s['spacing'] == 20.0,
      ),
    );
    expect(await morphShapes(), 1);
    await tester.tap(find.byIcon(Icons.add));
    await settle(tester, 10);
    expect(await morphShapes(), 2);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await settle(tester, 10);
    expect(await morphShapes(), 1);

    // Scrolling: the views follow the list without errors.
    final before = tester.getRect(find.text('Merged union (unionId)'));
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await settle(tester);
    expect(
      tester.getRect(find.text('Merged union (unionId)')).top,
      lessThan(before.top),
    );
    expect(tester.takeException(), isNull);
  });
}
