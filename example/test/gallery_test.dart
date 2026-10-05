import 'package:adaptive_liquid_glass_example/demo.dart';
import 'package:adaptive_liquid_glass_example/gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the demo opens the gallery, and every recipe builds', (t) async {
    await t.pumpWidget(const MaterialApp(home: Demo()));
    await t.tap(find.text('Gallery'));
    await t.pumpAndSettle();
    expect(find.byType(Gallery), findsOneWidget);

    await t.tap(find.text('Continue'));
    await t.pump();
    expect(find.text('Pressed'), findsOneWidget);

    await t.scrollUntilVisible(find.byIcon(Icons.add), 200);
    await t.tap(find.byIcon(Icons.add));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await t.scrollUntilVisible(find.text('Tinted'), 200);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
