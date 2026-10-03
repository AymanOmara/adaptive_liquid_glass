import 'dart:math' as math;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('defaults without a theme', (tester) async {
    late LiquidGlassThemeData data;
    await tester.pumpWidget(Builder(builder: (c) {
      data = LiquidGlassTheme.of(c);
      return const SizedBox();
    }));
    expect(data.lightAngle, closeTo(-3 * math.pi / 4, 1e-12));
    expect(data.defaultGlass, Glass.regular);
    expect(data.defaultMode, GlassRenderMode.auto);
    expect(data.nativeEnabled, isFalse);
  });

  testWidgets('nearest theme wins and notifies on change', (tester) async {
    late LiquidGlassThemeData data;
    Widget app(bool native) => LiquidGlassTheme(
          data: LiquidGlassThemeData(nativeEnabled: native),
          child: Builder(builder: (c) {
            data = LiquidGlassTheme.of(c);
            return const SizedBox();
          }),
        );
    await tester.pumpWidget(app(false));
    expect(data.nativeEnabled, isFalse);
    await tester.pumpWidget(app(true));
    expect(data.nativeEnabled, isTrue);
  });
}
