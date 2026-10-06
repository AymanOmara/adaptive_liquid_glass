import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/interaction/glass_focus_ring.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

/// The ring painter under the first [GlassFocusRing], or null.
CustomPainter? _ring(WidgetTester t) => t
    .widget<CustomPaint>(
      find
          .descendant(
            of: find.byType(GlassFocusRing),
            matching: find.byType(CustomPaint),
          )
          .first,
    )
    .foregroundPainter;

Widget _button({VoidCallback? onPressed, GlassShape? shape}) => LiquidGlass(
  onPressed: onPressed,
  shape: shape ?? const GlassShape.capsule(),
  padding: const EdgeInsets.all(12),
  child: const Text('Go'),
);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() {
    GlassPlatform.instance.debugReset();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  for (final (name, variant) in [('shader', ios), ('Material', android)]) {
    testWidgets('$name: keyboard focus draws a ring, blur removes it', (
      t,
    ) async {
      shaderEnv();
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      final other = FocusNode();
      addTearDown(other.dispose);
      await t.pumpWidget(
        appHost(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _button(onPressed: () {}),
              Focus(focusNode: other, child: const SizedBox(height: 8)),
            ],
          ),
        ),
      );
      expect(_ring(t), isNull);
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(_ring(t), isNotNull);
      final ring = find
          .descendant(
            of: find.byType(GlassFocusRing),
            matching: find.byType(CustomPaint),
          )
          .first;
      expect(
        t.renderObject(ring),
        // The ring paints last, over the surface (and its shadow).
        paints..something((method, args) {
          if (method != #drawPath) return false;
          final paint = args[1] as Paint;
          return paint.style == PaintingStyle.stroke &&
              paint.color.toARGB32() ==
                  CupertinoColors.activeBlue.color.toARGB32();
        }),
      );
      other.requestFocus();
      await t.pump();
      await t.pump();
      expect(_ring(t), isNull);
    }, variant: variant);

    testWidgets('$name: touch focus draws no ring', (t) async {
      shaderEnv();
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      await t.pumpWidget(appHost(_button(onPressed: () {})));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      expect(_ring(t), isNull);
    }, variant: variant);

    testWidgets('$name: disabled glass never shows a ring', (t) async {
      shaderEnv();
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await t.pumpWidget(appHost(_button()));
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(_ring(t), isNull);
    }, variant: variant);
  }

  testWidgets('switching to keyboard mode while focused shows the ring', (
    t,
  ) async {
    shaderEnv();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await t.pumpWidget(appHost(_button(onPressed: () {})));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_ring(t), isNull);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await t.pump();
    expect(_ring(t), isNotNull);
  }, variant: ios);

  testWidgets('the degraded path keeps the ring outside its clip', (t) async {
    GlassPlatform.instance.debugEnvironment = GlassEnvironment(
      platform: defaultTargetPlatform,
      iosMajorVersion: 18,
      reduceTransparency: false,
      shaderSupported: false,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await t.pumpWidget(appHost(_button(onPressed: () {})));
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_ring(t), isNotNull);
    expect(
      find.ancestor(
        of: find.byType(GlassFocusRing),
        matching: find.byType(ClipPath),
      ),
      findsNothing,
    );
  }, variant: ios);

  testWidgets('the ring follows a rect shape', (t) async {
    shaderEnv();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await t.pumpWidget(
      appHost(_button(onPressed: () {}, shape: const GlassShape.rect(12))),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(
      t.widget<GlassFocusRing>(find.byType(GlassFocusRing)).shape,
      const GlassShape.rect(12),
    );
    expect(_ring(t), isNotNull);
  }, variant: ios);

  testWidgets('GlassToggle rings its track on keyboard focus', (t) async {
    shaderEnv();
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await t.pumpWidget(appHost(GlassToggle(value: false, onChanged: (_) {})));
    expect(_ring(t), isNull);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_ring(t), isNotNull);
    expect(
      t.getSize(find.byType(GlassFocusRing)),
      t.getSize(find.byType(GlassToggle)),
    );
  }, variant: ios);
}
