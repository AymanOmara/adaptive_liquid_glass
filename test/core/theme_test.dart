import 'dart:math' as math;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('defaults without a theme', (tester) async {
    late LiquidGlassThemeData data;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          data = LiquidGlassTheme.of(c);
          return const SizedBox();
        },
      ),
    );
    expect(data.lightAngle, closeTo(-3 * math.pi / 4, 1e-12));
    expect(data.defaultGlass, Glass.regular);
    expect(data.defaultMode, GlassRenderMode.auto);
  });

  testWidgets('nearest theme wins and notifies on change', (tester) async {
    late LiquidGlassThemeData data;
    Widget app(GlassRenderMode mode) => LiquidGlassTheme(
      data: LiquidGlassThemeData(defaultMode: mode),
      child: Builder(
        builder: (c) {
          data = LiquidGlassTheme.of(c);
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(app(GlassRenderMode.auto));
    expect(data.defaultMode, GlassRenderMode.auto);
    await tester.pumpWidget(app(GlassRenderMode.shader));
    expect(data.defaultMode, GlassRenderMode.shader);
  });
}
