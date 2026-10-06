import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_program.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_shape_uniform.dart';
import 'package:adaptive_liquid_glass/src/shader/glass_uniforms.dart';
import 'package:adaptive_liquid_glass/src/shader/texture_space.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const shapeGlobal = Rect.fromLTWH(100, 200, 200, 60);
const filterBounds = Rect.fromLTWH(60, 160, 280, 140);

/// Luminance readout of one render of the glass over 40 stripes.
class Readout {
  Readout(this.mid, this.far, this.nearEdge, this.rowMin, this.rowMax);

  final int mid;
  final int far;
  final int nearEdge;
  final int rowMin;
  final int rowMax;

  @override
  String toString() =>
      'mid=$mid far=$far nearEdge=$nearEdge centreRow=[$rowMin, $rowMax]';
}

/// Draws the regular glass shader (with [constants]) over black/white
/// stripes, composed after the frost blur as RenderGlassBackdrop does, and
/// reads pixels back.
Future<Readout> renderGlass(
  WidgetTester tester,
  GlassConstants constants,
) async {
  final shader = GlassProgram.instance.program.value!.fragmentShader();
  final dpr = tester.view.devicePixelRatio;
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
      constants: constants,
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
                  // Same composition as RenderGlassBackdrop: frost blur
                  // (logical px) first, then the glass shader.
                  filter: ui.ImageFilter.compose(
                    outer: ui.ImageFilter.shader(shader),
                    inner: ui.ImageFilter.blur(
                      sigmaX: constants.regular.blurSigma,
                      sigmaY: constants.regular.blurSigma,
                      tileMode: TileMode.clamp,
                    ),
                  ),
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

  // Stripe i (odd = light) spans [i, i + 1) × screenWidth / 40.
  final stripe = tester.view.physicalSize.width / dpr / 40;
  // Frost uniformity across the centre row, inside the lens band.
  final row = [
    for (var x = shapeGlobal.left + 30; x <= shapeGlobal.right - 30; x += 1)
      lum(Offset(x, shapeGlobal.center.dy)),
  ];
  return Readout(
    lum(shapeGlobal.center),
    lum(const Offset(64, 164)),
    // Just outside the bottom edge, on a light stripe.
    lum(Offset(19.5 * stripe, shapeGlobal.bottom + 2)),
    row.reduce((a, b) => a < b ? a : b),
    row.reduce((a, b) => a > b ? a : b),
  );
}

/// [GlassConstants.standard] with the regular set's keys in [regular]
/// overridden.
GlassConstants withRegular(Map<String, Object?> regular) =>
    GlassConstants.fromJson({'regular': regular});

void main() {
  // Readback via RepaintBoundary.toImage; see probe_test.dart for why
  // binding.takeScreenshot is not used on iOS.
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GlassProgram.instance.load());

  testWidgets('glass shader changes pixels only near the shape', (
    tester,
  ) async {
    final r = await renderGlass(tester, GlassConstants.standard);
    // ignore: avoid_print
    print('SMOKE $r');
    // Centre of the glass: blurred stripes → mid grey, not pure black/white.
    expect(r.mid, inInclusiveRange(40, 230));
    // Far outside the shadow: untouched stripe values.
    expect(r.far == 0x10 || r.far == 0xF0, isTrue, reason: 'far=${r.far}');
    // The shadow darkens the light stripe next to the shape.
    expect(
      r.nearEdge,
      allOf(lessThan(0xF0), greaterThan(0x10)),
      reason: 'shadow missing next to the shape',
    );
  });

  testWidgets('per-shape fill factor (uInfo.w < 1) weakens the white fill', (
    tester,
  ) async {
    // halfMin 30 pt. fillSizeRef 0: factor 1. ref 120 / drop 0.8: factor
    // 1 − 0.8 × (1 − 30 / 120) = 0.4, so the centre moves from the white
    // fill toward the (mid-grey) blurred stripes.
    final full = await renderGlass(tester, withRegular({'fillSizeRef': 0.0}));
    final weak = await renderGlass(
      tester,
      withRegular({'fillSizeRef': 120.0, 'fillSizeDrop': 0.8}),
    );
    // ignore: avoid_print
    print('SMOKE fill factor 1: $full; 0.4: $weak');
    expect(weak.mid, lessThan(full.mid - 10));
    expect(weak.far, full.far);
  });

  testWidgets('frost v2 wide taps flatten the centre row', (tester) async {
    // A small core blur leaves stripe ripple across the centre; mixing in
    // the 16-tap wide tail (w = 1) removes most of it.
    const core = {'blurSigma': 2.0, 'blurSizeRef': 0.0, 'fillOpacity': 0.3};
    final off = await renderGlass(tester, withRegular(core));
    final on = await renderGlass(
      tester,
      withRegular({
        ...core,
        'frostWideSigma': 8.0,
        'frostWideMixEdge': 1.0,
        'frostWideMixCentre': 1.0,
      }),
    );
    // ignore: avoid_print
    print('SMOKE frost tail off: $off; on: $on');
    expect(off.rowMax - off.rowMin, greaterThan(40));
    expect(
      on.rowMax - on.rowMin,
      lessThan((off.rowMax - off.rowMin) ~/ 2),
    );
  });
}
