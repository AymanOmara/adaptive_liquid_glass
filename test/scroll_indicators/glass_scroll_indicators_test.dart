import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/scroll_indicators/scroll_indicator_metrics.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

Widget _list({
  GlassScrollIndicatorVisibility visibility =
      GlassScrollIndicatorVisibility.automatic,
  GlassRenderMode? mode,
  ScrollController? controller,
}) => MaterialApp(
  home: GlassScrollIndicators(
    visibility: visibility,
    mode: mode,
    controller: controller,
    child: ListView(
      controller: controller,
      children: [
        for (var i = 0; i < 60; i++) SizedBox(height: 40, child: Text('$i')),
      ],
    ),
  ),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  test('visibility shows only for automatic and visible', () {
    expect(GlassScrollIndicatorVisibility.automatic.shows, isTrue);
    expect(GlassScrollIndicatorVisibility.visible.shows, isTrue);
    expect(GlassScrollIndicatorVisibility.hidden.shows, isFalse);
    expect(GlassScrollIndicatorVisibility.never.shows, isFalse);
  });

  testWidgets('glass path: a UIKit-style bar, not draggable', (t) async {
    shaderEnv();
    await t.pumpWidget(_list());
    final bar = t.widget<RawScrollbar>(find.byType(RawScrollbar));
    expect(bar.thickness, ScrollIndicatorMetrics.thickness);
    expect(bar.interactive, isFalse);
    expect(bar.thumbVisibility, isFalse);
    expect(find.byType(Scrollbar), findsNothing);
  }, variant: ios);

  testWidgets('hidden and never draw no bar', (t) async {
    shaderEnv();
    for (final v in [
      GlassScrollIndicatorVisibility.hidden,
      GlassScrollIndicatorVisibility.never,
    ]) {
      await t.pumpWidget(_list(visibility: v));
      expect(find.byType(RawScrollbar), findsNothing);
    }
  }, variant: ios);

  testWidgets('hidden also turns off the desktop scrollbar', (t) async {
    await t.pumpWidget(
      _list(visibility: GlassScrollIndicatorVisibility.hidden),
    );
    expect(find.byType(RawScrollbar), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('visible stays shown on pointer platforms', (t) async {
    final c = ScrollController();
    addTearDown(c.dispose);
    await t.pumpWidget(
      _list(
        visibility: GlassScrollIndicatorVisibility.visible,
        mode: GlassRenderMode.shader,
        controller: c,
      ),
    );
    expect(
      t.widget<RawScrollbar>(find.byType(RawScrollbar)).thumbVisibility,
      isTrue,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Material path uses Material Scrollbar', (t) async {
    await t.pumpWidget(_list(mode: GlassRenderMode.material));
    expect(find.byType(Scrollbar), findsOneWidget);
  }, variant: android);
}
