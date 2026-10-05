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
    // The loading button's spinner never settles: pump fixed durations.
    await t.pump(const Duration(seconds: 1));
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await t.scrollUntilVisible(find.text('Tinted'), 200);

    await t.scrollUntilVisible(find.text('Snippets'), 200);
    await t.tap(find.text('Snippets'));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);

    await t.scrollUntilVisible(find.text('Open a large-title page'), 200);
    expect(find.text('Prominent'), findsOneWidget);
    await t.tap(find.text('Open a large-title page'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
