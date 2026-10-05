import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/group/glass_member.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hosts.dart';

Glass _drawnGlass(WidgetTester t) =>
    t.widget<GlassMember>(find.byType(GlassMember)).glass;

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() => GlassPlatform.instance.debugReset());

  for (final (name, variant) in [('shader', ios), ('Material', android)]) {
    testWidgets('$name: tapping the glass calls onPressed', (t) async {
      shaderEnv();
      var taps = 0;
      await t.pumpWidget(
        appHost(
          LiquidGlass(
            onPressed: () => taps++,
            padding: const EdgeInsets.all(12),
            child: const Text('Go'),
          ),
        ),
      );
      await t.tap(find.text('Go'));
      expect(taps, 1);
      // The padding is part of the button (inside the capsule's end cap).
      await t.tapAt(
        t
            .getCenter(find.byType(LiquidGlass))
            .translate(-t.getSize(find.byType(LiquidGlass)).width / 2 + 8, 0),
      );
      expect(taps, 2);
    }, variant: variant);

    testWidgets('$name: pressable glass is a focusable button', (t) async {
      shaderEnv();
      final semantics = t.ensureSemantics();
      await t.pumpWidget(
        appHost(LiquidGlass(onPressed: () {}, child: const Text('Go'))),
      );
      expect(
        t.getSemantics(find.text('Go')),
        isSemantics(
          label: 'Go',
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      semantics.dispose();
    }, variant: variant);

    testWidgets('$name: keyboard activation calls onPressed', (t) async {
      shaderEnv();
      var taps = 0;
      await t.pumpWidget(
        appHost(LiquidGlass(onPressed: () => taps++, child: const Text('Go'))),
      );
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pump();
      expect(taps, 1);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      await t.pump();
      expect(taps, 2);
    }, variant: variant);
  }

  testWidgets('without onPressed the glass is not a button', (t) async {
    shaderEnv();
    final semantics = t.ensureSemantics();
    await t.pumpWidget(appHost(const LiquidGlass(child: Text('Hi'))));
    expect(t.getSemantics(find.text('Hi')), isNot(isSemantics(isButton: true)));
    semantics.dispose();
  }, variant: ios);

  testWidgets('onPressed makes the default glass interactive', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(LiquidGlass(onPressed: () {}, child: const Text('Go'))),
    );
    expect(_drawnGlass(t).isInteractive, isTrue);
  }, variant: ios);

  testWidgets('onPressed makes a given glass interactive', (t) async {
    shaderEnv();
    await t.pumpWidget(
      plainHost(
        LiquidGlass(
          glass: Glass.clear.tint(Colors.blue),
          onPressed: () {},
          child: const Text('Go'),
        ),
      ),
    );
    expect(_drawnGlass(t), Glass.clear.tint(Colors.blue).interactive());
  }, variant: ios);

  testWidgets('interactive(false) opts out of the press visuals', (t) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      appHost(
        LiquidGlass(
          glass: Glass.regular.interactive(false),
          onPressed: () => taps++,
          child: const Text('Go'),
        ),
      ),
    );
    expect(_drawnGlass(t).isInteractive, isFalse);
    await t.tap(find.text('Go'));
    expect(taps, 1);
  }, variant: ios);

  testWidgets('Material: interactive(false) still taps, without ripple', (
    t,
  ) async {
    shaderEnv();
    var taps = 0;
    await t.pumpWidget(
      appHost(
        LiquidGlass(
          glass: Glass.regular.interactive(false),
          onPressed: () => taps++,
          child: const Text('Go'),
        ),
      ),
    );
    expect(find.byType(InkWell), findsNothing);
    await t.tap(find.text('Go'));
    expect(taps, 1);
  }, variant: android);

  testWidgets('Glass.interactive(false) differs from the plain preset', (
    t,
  ) async {
    expect(Glass.regular.interactive(false), isNot(Glass.regular));
    expect(Glass.regular.interactive(false).isInteractive, isFalse);
  });
}
