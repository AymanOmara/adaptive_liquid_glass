import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/glass_testing.dart';
import 'package:adaptive_liquid_glass_example/android_glass_toggle.dart';
import 'package:adaptive_liquid_glass_example/demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    GlassTesting.reset();
    androidLiquidGlass.value = false;
  });

  bool flagAt(WidgetTester t, Finder f) =>
      LiquidGlassTheme.of(t.element(f)).supportLiquidGlassOnAndroid;

  testWidgets('the Android toggle switches the iOS glass on and off', (
    t,
  ) async {
    GlassTesting.setUp();
    await t.pumpWidget(
      const AndroidGlassTheme(
        data: LiquidGlassThemeData(),
        child: MaterialApp(home: Demo()),
      ),
    );
    final toggle = find.byType(GlassToggle);
    expect(toggle, findsOneWidget);
    expect(flagAt(t, toggle), isFalse);

    await t.tap(toggle);
    await t.pumpAndSettle();
    expect(androidLiquidGlass.value, isTrue);
    expect(flagAt(t, find.byType(Demo)), isTrue);
    expect(t.takeException(), isNull);

    await t.tap(find.byType(GlassToggle));
    await t.pumpAndSettle();
    expect(flagAt(t, find.byType(Demo)), isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('no toggle on iOS', (t) async {
    GlassTesting.setUp(iosMajorVersion: 18);
    await t.pumpWidget(
      const AndroidGlassTheme(
        data: LiquidGlassThemeData(),
        child: MaterialApp(home: Demo()),
      ),
    );
    expect(find.byType(GlassToggle), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
