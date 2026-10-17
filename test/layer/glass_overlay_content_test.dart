import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/core/glass_environment.dart';
import 'package:adaptive_liquid_glass/src/layer/glass_layer.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_backdrop.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/render_glass_backdrop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void env() {
  GlassPlatform.instance.debugEnvironment = GlassEnvironment(
    platform: defaultTargetPlatform,
    iosMajorVersion: null,
    reduceTransparency: false,
    shaderSupported: true,
  );
}

Widget app(Widget home) => LiquidGlassTheme(
  data: const LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
  child: MaterialApp(home: home),
);

Widget button(String label) => LiquidGlass(
  child: SizedBox(width: 80, height: 40, child: Center(child: Text(label))),
);

Widget overlay() => const GlassOverlayContent(
  child: ColoredBox(
    color: Color(0xFFFF0000),
    child: SizedBox(width: 40, height: 20),
  ),
);

List<RenderGlassBackdrop> backdrops(WidgetTester t) => t
    .renderObjectList<RenderGlassBackdrop>(find.byType(GlassBackdrop))
    .toList();

final android = TargetPlatformVariant.only(TargetPlatform.android);

void main() {
  setUp(() => GlassProgram.instance.debugReset(skipLoad: true));
  tearDown(() {
    GlassPlatform.instance.debugReset();
    GlassSharedLayer.debugEnabled = null;
  });

  testWidgets('overlay content shares the layer and draws after the glass', (
    t,
  ) async {
    env();
    await t.pumpWidget(
      app(
        Scaffold(
          body: Stack(
            children: [
              Positioned(left: 0, top: 0, child: button('glass')),
              Positioned(left: 20, top: 10, child: overlay()),
            ],
          ),
        ),
      ),
    );
    await t.pump();
    final overlayBackdrop = t.renderObject<RenderGlassBackdrop>(
      find.descendant(
        of: find.byType(GlassOverlayContent),
        matching: find.byType(GlassBackdrop),
      ),
    );
    final glass = backdrops(t).firstWhere((b) => b != overlayBackdrop);
    expect(overlayBackdrop.sharedLayer, same(glass.sharedLayer));
    final plan = overlayBackdrop.sharedLayer!.debugLastPlan!;
    int stratumOf(Object id) => plan.indexWhere((s) => s.groups.contains(id));
    expect(stratumOf(glass), isNonNegative);
    expect(stratumOf(overlayBackdrop), greaterThanOrEqualTo(stratumOf(glass)));
    // Within the stratum the content composites after the glass, in paint
    // order.
    expect(
      plan[stratumOf(overlayBackdrop)].groups.indexOf(overlayBackdrop),
      greaterThan(plan[stratumOf(glass)].groups.indexOf(glass)),
    );
  }, variant: android);

  testWidgets('off the shared layer the content paints in place', (t) async {
    env();
    await t.pumpWidget(
      app(
        Scaffold(
          body: Stack(
            children: [
              Positioned(left: 0, top: 0, child: button('glass')),
              Positioned(left: 20, top: 10, child: overlay()),
            ],
          ),
        ),
      ),
    );
    final overlayBackdrop = t.renderObject<RenderGlassBackdrop>(
      find.descendant(
        of: find.byType(GlassOverlayContent),
        matching: find.byType(GlassBackdrop),
      ),
    );
    expect(overlayBackdrop.sharedLayer, isNull);
    // No slot defers it; the child is found and painted in the scene.
    expect(find.byType(ColoredBox), findsOneWidget);
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.descendant(
        of: find.byType(GlassOverlayContent),
        matching: find.byType(RepaintBoundary),
      ),
    );
    Layer? l = boundary.debugLayer;
    while (l != null && l.parent != null) {
      l = l.parent;
    }
    expect(l, isNotNull);
    expect(l!.attached, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
