import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/glass_testing.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app() => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 300,
        child: GlassSegmentedControl<int>(
          segments: const [
            GlassSegment(value: 0, label: Text('A')),
            GlassSegment(value: 1, label: Text('B')),
          ],
          selected: 0,
          onChanged: (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  tearDown(GlassTesting.reset);

  testWidgets('iOS before 26: the glass path', (t) async {
    GlassTesting.setUp(iosMajorVersion: 18);
    await t.pumpWidget(_app());
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android: the Material path', (t) async {
    GlassTesting.setUp();
    await t.pumpWidget(_app());
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('an explicit platform wins over the variant', (t) async {
    GlassTesting.setUp(platform: TargetPlatform.android);
    await t.pumpWidget(_app());
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('shaders do not load until reset', () async {
    GlassTesting.setUp();
    await LiquidGlass.precache();
    expect(GlassProgram.instance.program.value, isNull);
    GlassTesting.reset();
    expect(
      GlassPlatform.instance.environment.value.platform,
      defaultTargetPlatform,
    );
  });
}
