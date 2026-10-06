import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  test('glassEffect() is regular-by-theme glass in a capsule', () {
    const text = Text('Hello');
    final glass = text.glassEffect();
    expect(glass, isA<LiquidGlass>());
    expect(glass.child, same(text));
    expect(glass.glass, isNull); // the theme's defaultGlass
    expect(glass.shape, const GlassShape.capsule());
    expect(glass.glassId, isNull);
    expect(glass.unionId, isNull);
    expect(glass.padding, isNull);
    expect(glass.onPressed, isNull);
  });

  test('glassEffect forwards glass, shape, glassId, unionId and padding', () {
    const icon = Icon(Icons.add);
    final g = Glass.clear.interactive();
    final glass = icon.glassEffect(
      glass: g,
      shape: const GlassShape.circle(),
      glassId: 'plus',
      unionId: 'tools',
      padding: const EdgeInsetsDirectional.all(8),
    );
    expect(glass.glass, g);
    expect(glass.shape, const GlassShape.circle());
    expect(glass.glassId, 'plus');
    expect(glass.unionId, 'tools');
    expect(glass.padding, const EdgeInsetsDirectional.all(8));
    expect(glass.child, same(icon));
  });

  testWidgets('one line draws glass', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(const SizedBox(width: 80, height: 40).glassEffect()),
    );
    final frame = t
        .renderObject<RenderGlassBackdrop>(find.byType(GlassBackdrop))
        .debugLastFrame!;
    expect(frame.uniforms.shapes, hasLength(1));
  }, variant: ios);

  test('glassEffect forwards onPressed', () {
    void tap() {}
    expect(const Text('Go').glassEffect(onPressed: tap).onPressed, tap);
  });

  for (final (name, variant) in [('shader', ios), ('Material', android)]) {
    testWidgets('$name: one line makes a glass button', (t) async {
      shaderEnv();
      var taps = 0;
      await t.pumpWidget(
        appHost(
          const Text('Go').glassEffect(
            padding: const EdgeInsets.all(12),
            onPressed: () => taps++,
          ),
        ),
      );
      await t.tap(find.text('Go'));
      expect(taps, 1);
    }, variant: variant);
  }
}
