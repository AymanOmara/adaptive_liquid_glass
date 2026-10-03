import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_uniforms.dart';
import 'package:adaptive_liquid_glass/src/shader/texture_space.dart';
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  // Readback via RepaintBoundary.toImage; see probe_test.dart for why
  // binding.takeScreenshot is not used on iOS.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('glass shader changes pixels only near the shape', (
    tester,
  ) async {
    await GlassProgram.instance.load();
    final shader = GlassProgram.instance.program.value!.fragmentShader();
    final dpr = tester.view.devicePixelRatio;
    const shapeGlobal = Rect.fromLTWH(100, 200, 200, 60);
    const filterBounds = Rect.fromLTWH(60, 160, 280, 140);
    final floats = packGlassUniforms(
      GlassFrameUniforms(
        shapes: [
          GlassShapeUniform(
            rect: toTextureSpace(
              shapeGlobal,
              filterOriginGlobal: filterBounds.topLeft,
              devicePixelRatio: dpr,
            ),
            radius: 30 * dpr,
            variant: GlassVariant.regular,
          ),
        ],
        devicePixelRatio: dpr,
        lightAngle: -2.356,
        smoothing: 0,
        constants: GlassConstants.standard,
      ),
    );
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(kFirstUserFloat + i, floats[i]);
    }

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              // Stripes so lensing and blur are visible.
              Positioned.fill(
                child: Row(
                  // Childless ColoredBoxes need tight height or they are 0 tall.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < 40; i++)
                      Expanded(
                        child: ColoredBox(
                          color: i.isEven
                              ? const Color(0xFF101010)
                              : const Color(0xFFF0F0F0),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned.fromRect(
                rect: filterBounds,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.shader(shader),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    int lum(Offset p) {
      final i = ((p.dy * dpr).round() * image.width + (p.dx * dpr).round()) * 4;
      return data.getUint8(i);
    }

    // Centre of the glass: blurred stripes → mid grey, not pure black/white.
    final mid = lum(shapeGlobal.center);
    expect(mid, inInclusiveRange(40, 230));
    // Far outside the shadow: untouched stripe values.
    final far = lum(const Offset(64, 164));
    expect(far == 0x10 || far == 0xF0, isTrue, reason: 'far=$far');
    // Just outside the bottom edge, on a light stripe: the shadow darkens it.
    // Stripe i (odd = light) spans [i, i + 1) × screenWidth / 40.
    final stripe = tester.view.physicalSize.width / dpr / 40;
    final nearEdge = lum(Offset(19.5 * stripe, shapeGlobal.bottom + 2));
    // ignore: avoid_print
    print('SMOKE mid=$mid far=$far nearEdge=$nearEdge');
    expect(
      nearEdge,
      allOf(lessThan(0xF0), greaterThan(0x10)),
      reason: 'shadow missing next to the shape',
    );
  });
}
