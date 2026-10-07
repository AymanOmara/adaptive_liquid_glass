import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  test('frosted and crystal alias regular and clear', () {
    expect(Glass.frosted, Glass.regular);
    expect(Glass.frosted, same(Glass.regular));
    expect(Glass.crystal, Glass.clear);
    expect(Glass.crystal, same(Glass.clear));
  });

  test('smoke is regular glass with the smoke tint', () {
    expect(Glass.smoke.variant, GlassVariant.regular);
    expect(Glass.smoke.tintColor, GlassColors.smokeTint);
    expect(Glass.smoke.isInteractive, isFalse);
    expect(Glass.smoke, Glass.regular.tint(GlassColors.smokeTint));
    expect(GlassColors.smokeTint.a, closeTo(0.35, 0.01));
  });

  test('tinted is shorthand for regular.tint', () {
    const c = Color(0xFFAA3366);
    expect(Glass.tinted(c), Glass.regular.tint(c));
    expect(Glass.tinted(c).hashCode, Glass.regular.tint(c).hashCode);
    expect(Glass.tinted(c).variant, GlassVariant.regular);
  });

  test('accent is regular glass tinted iOS 26 system blue', () {
    expect(Glass.accent.variant, GlassVariant.regular);
    expect(Glass.accent.tintColor, GlassSystemColors.blue);
    expect(Glass.accent, Glass.tinted(GlassSystemColors.blue));
  });

  test('presets chain like any Glass', () {
    final g = Glass.smoke.interactive();
    expect(g.isInteractive, isTrue);
    expect(g.tintColor, GlassColors.smokeTint);
    expect(Glass.smoke.isInteractive, isFalse);
    expect(
      Glass.crystal.tint(GlassSystemColors.blue).variant,
      GlassVariant.clear,
    );
    expect(Glass.accent.tint(null), Glass.frosted);
  });

  group('shader path', () {
    setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
    tearDown(() => GlassPlatform.instance.debugReset());

    testWidgets('LiquidGlass pumps with Glass.smoke', (t) async {
      shaderEnv();
      await t.pumpWidget(
        plainHost(
          const LiquidGlass(
            glass: Glass.smoke,
            child: SizedBox(width: 120, height: 48),
          ),
        ),
      );
      expect(find.byType(LiquidGlass), findsOneWidget);
      expect(t.takeException(), isNull);
    }, variant: ios);
  });
}
