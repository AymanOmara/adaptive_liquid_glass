import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/color_picker/app_capture.dart';
import 'package:adaptive_liquid_glass/src/color_picker/eyedropper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS app capture contains Flutter pixels and native glass', (
    t,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await AdaptiveLiquidGlass.initialize(mode: GlassRenderMode.native);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: const Scaffold(
          body: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: Color(0xFFFF0000))),
              Positioned(
                left: 20,
                top: 130,
                width: 150,
                height: 100,
                child: ColoredBox(color: Color(0xFF0000FF)),
              ),
              Positioned(
                left: 20,
                top: 470,
                child: LiquidGlass(
                  mode: GlassRenderMode.native,
                  padding: EdgeInsets.zero,
                  shape: GlassShape.rect(20),
                  child: SizedBox(width: 150, height: 100),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byType(UiKitView), findsOneWidget);
    // Let UIKit commit the embedded view before asking it to snapshot.
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    final capture = await t.runAsync(() => captureAppView(t.view));
    expect(capture, isNotNull);
    final image = capture!.image;
    late Color nativeGlass;
    try {
      final bytes = (await t.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
      ))!;
      Color at(Offset point) =>
          colorAtPixel(bytes, image.width, image.height, point * capture.ratio);
      expect(at(const Offset(200, 200)), const Color(0xFFFF0000));
      expect(at(const Offset(80, 180)), const Color(0xFF0000FF));
      // Native regular glass frosts the red backdrop: a Flutter-only
      // repaint-boundary snapshot would read unchanged red at this point.
      final glass = at(const Offset(80, 520));
      nativeGlass = glass;
      expect(glass.g, greaterThan(0.1));
      expect(glass.b, greaterThan(0.1));
      expect(glass.r, greaterThan(0.8));
    } finally {
      image.dispose();
    }
    final picking = pickColorFromApp(t.element(find.byType(LiquidGlass)));
    for (
      var i = 0;
      i < 20 && find.byType(EyedropperLoupe).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await t.pump();
    }
    expect(find.byType(EyedropperLoupe), findsOneWidget);
    await t.tapAt(const Offset(80, 520));
    await t.pump();
    final picked = await picking;
    expect(picked, isNotNull);
    expect((picked!.r - nativeGlass.r).abs(), lessThan(0.02));
    expect((picked.g - nativeGlass.g).abs(), lessThan(0.02));
    expect((picked.b - nativeGlass.b).abs(), lessThan(0.02));
  });
}
