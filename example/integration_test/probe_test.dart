import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Pixels are read back with RepaintBoundary.toImage at the screen origin.
  // binding.takeScreenshot is unusable on iOS here: drawViewHierarchyInRect
  // returned a stale frame ("Test starting...") as a 16-bit Display-P3 PNG.
  // A host `simctl io screenshot` matched this readback byte for byte; see
  // docs/superpowers/notes/shader-probe.md.

  testWidgets('backdrop shader texture space', (tester) async {
    expect(
      ui.ImageFilter.isShaderFilterSupported,
      isTrue,
      reason: 'Impeller must be on',
    );
    final program = await ui.FragmentProgram.fromAsset('shaders/probe.frag');
    final shader = program.fragmentShader();
    for (var i = 0; i < 16; i++) {
      shader.setFloat(2 + i, 0);
    }
    shader.setFloat(2 + 8, 0.25); // uArr[2].x

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFFFFFFFF)),
              ),
              Positioned(
                left: 200,
                top: 300,
                width: 100,
                height: 100,
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

    final dpr = tester.view.devicePixelRatio;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;

    List<double> px(double x, double y) {
      final i = ((y * dpr).round() * image.width + (x * dpr).round()) * 4;
      return [for (var c = 0; c < 3; c++) data.getUint8(i + c) / 255];
    }

    final c = px(250, 350);
    final widthFromB = c[2] * 4096;
    // ignore: avoid_print
    print(
      'PROBE screenPx=${image.width}x${image.height} dpr=$dpr '
      'center rgb=$c uSize.x≈$widthFromB',
    );

    final globalR = 250 * dpr / image.width;
    final isGlobal =
        (c[0] - globalR).abs() < 0.01 && (widthFromB - image.width).abs() < 24;
    final isLocal =
        (c[0] - 0.5).abs() < 0.01 && (widthFromB - 100 * dpr).abs() < 24;
    // ignore: avoid_print
    print(
      'PROBE result: ${isGlobal
          ? 'global'
          : isLocal
          ? 'local'
          : 'UNKNOWN'}',
    );
    expect(c[2], greaterThan(0), reason: 'uniform array indexing failed');
    expect(isGlobal || isLocal, isTrue);
  });

  // Same filter, but inside an Opacity saveLayer whose subtree does not
  // start at the screen origin: is the space screen-global or relative to
  // the offscreen layer (origin 150,250, 200×200)?
  testWidgets('backdrop shader texture space inside a saveLayer', (
    tester,
  ) async {
    const opacity = 0.99;
    final program = await ui.FragmentProgram.fromAsset('shaders/probe.frag');
    final shader = program.fragmentShader();
    for (var i = 0; i < 16; i++) {
      shader.setFloat(2 + i, 0);
    }
    shader.setFloat(2 + 8, 0.25); // uArr[2].x

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFFFFFFFF)),
              ),
              Positioned(
                left: 150,
                top: 250,
                width: 200,
                height: 200,
                child: Opacity(
                  opacity: opacity,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 50,
                        top: 50,
                        width: 100,
                        height: 100,
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
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dpr = tester.view.devicePixelRatio;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: dpr);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;

    // Undo the 0.99 opacity over the white backdrop: c' = a·c + (1 − a).
    List<double> px(double x, double y) {
      final i = ((y * dpr).round() * image.width + (x * dpr).round()) * 4;
      return [
        for (var c = 0; c < 3; c++)
          (data.getUint8(i + c) / 255 - (1 - opacity)) / opacity,
      ];
    }

    final c = px(250, 350);
    final widthFromB = c[2] * 4096;
    // ignore: avoid_print
    print(
      'PROBE saveLayer screenPx=${image.width}x${image.height} dpr=$dpr '
      'center rgb=$c uSize.x≈$widthFromB',
    );

    bool matches(Offset origin, Size size) =>
        (c[0] - (250 - origin.dx) * dpr / size.width).abs() < 0.01 &&
        (c[1] - (350 - origin.dy) * dpr / size.height).abs() < 0.01 &&
        (widthFromB - size.width).abs() < 24;
    final screen = Size(image.width.toDouble(), image.height.toDouble());
    final isGlobal = matches(Offset.zero, screen);
    final isLayer = matches(const Offset(150, 250), const Size(600, 600));
    final isLocal = matches(const Offset(200, 300), const Size(300, 300));
    // ignore: avoid_print
    print(
      'PROBE saveLayer result: ${isGlobal
          ? 'global'
          : isLayer
          ? 'layer-relative'
          : isLocal
          ? 'local'
          : 'UNKNOWN'}',
    );
    expect(
      isGlobal,
      isTrue,
      reason:
          'kGlassTextureSpace assumes screen-global coordinates inside '
          'saveLayers; see docs/superpowers/notes/shader-probe.md',
    );
  });

  // Shader model v2 composes the frost blur before the shader:
  // ImageFilter.compose(outer: shader, inner: blur). The probe shader writes
  // FlutterFragCoord and uSize exactly (low byte, high byte, fraction) so the
  // mapping can be read back without 8-bit quantisation. Measured (see
  // docs/superpowers/notes/shader-probe.md): FlutterFragCoord stays
  // screen-global; uSize becomes the blurred input's size, which is the
  // screen grown on the right and bottom only, so `px / uSize` still samples
  // the pixel under `px`.
  testWidgets('backdrop shader texture space under a composed blur', (
    tester,
  ) async {
    final program = await ui.FragmentProgram.fromAsset('shaders/probe.frag');
    final dpr = tester.view.devicePixelRatio;
    final screen = tester.view.physicalSize;

    Future<ByteData> render(ui.ImageFilter filter, Rect box, Widget bg) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                Positioned.fill(child: bg),
                Positioned.fromRect(
                  rect: box,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: filter,
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
      expect(image.width, screen.width.round());
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    }

    ui.ImageFilter composed(ui.FragmentShader s, double sigma) =>
        ui.ImageFilter.compose(
          outer: ui.ImageFilter.shader(s),
          inner: ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
        );

    ui.FragmentShader probe({int mode = 0, bool passThrough = false}) {
      final s = program.fragmentShader();
      for (var i = 0; i < 16; i++) {
        s.setFloat(2 + i, 0);
      }
      s.setFloat(2 + 12, passThrough ? 1 : 0); // uArr[3].x
      s.setFloat(2 + 13, mode.toDouble()); // uArr[3].y
      return s;
    }

    const white = ColoredBox(color: Color(0xFFFFFFFF));
    for (final sigma in const [8.0, 20.0]) {
      for (final box in const [
        Rect.fromLTWH(200, 300, 100, 100),
        Rect.fromLTWH(40, 600, 300, 60),
      ]) {
        final w = screen.width.round();
        final values = <List<double>>[];
        for (var mode = 1; mode <= 4; mode++) {
          final data = await render(
            composed(probe(mode: mode), sigma),
            box,
            white,
          );
          double read(int x, int y) {
            final i = (y * w + x) * 4;
            return data.getUint8(i) +
                data.getUint8(i + 1) * 256 +
                data.getUint8(i + 2) / 255;
          }

          final x0 = (box.left * dpr).round(), y0 = (box.top * dpr).round();
          final x1 = (box.right * dpr).round() - 1;
          final y1 = (box.bottom * dpr).round() - 1;
          values.add([read(x0, y0), read(x1, y1)]);
          if (mode == 1) {
            expect(values.last, [
              closeTo(x0 + 0.5, 0.01),
              closeTo(x1 + 0.5, 0.01),
            ], reason: 'FlutterFragCoord.x is not screen-global');
          } else if (mode == 2) {
            expect(values.last, [
              closeTo(y0 + 0.5, 0.01),
              closeTo(y1 + 0.5, 0.01),
            ], reason: 'FlutterFragCoord.y is not screen-global');
          }
        }
        // ignore: avoid_print
        print(
          'PROBE composed sigma=$sigma box=$box '
          'fragX=${values[0]} fragY=${values[1]} '
          'uSize=(${values[2][0]}, ${values[3][0]}) '
          'screen=${screen.width}x${screen.height}',
        );
        expect(values[2][0], greaterThanOrEqualTo(screen.width));
        expect(values[3][0], greaterThanOrEqualTo(screen.height));
      }

      // Alignment: sampling at px / uSize must return the pixel under px.
      // A hard edge at logical x = 200 (black left) and y = 350 (black top)
      // must stay centred there after the symmetric blur.
      for (final vertical in const [true, false]) {
        final data = await render(
          composed(probe(passThrough: true), sigma),
          const Rect.fromLTWH(100, 250, 200, 200),
          Stack(
            children: [
              const Positioned.fill(child: white),
              Positioned(
                left: 0,
                top: 0,
                width: vertical ? 200 : null,
                right: vertical ? null : 0,
                height: vertical ? null : 350,
                bottom: vertical ? 0 : null,
                child: const ColoredBox(color: Color(0xFF000000)),
              ),
            ],
          ),
        );
        final w = screen.width.round();
        double v(int i) {
          final x = vertical ? i : (200 * dpr).round();
          final y = vertical ? (350 * dpr).round() : i;
          return data.getUint8((y * w + x) * 4) / 255;
        }

        final from = ((vertical ? 110 : 260) * dpr).round();
        final to = ((vertical ? 290 : 440) * dpr).round();
        var mid = double.nan;
        for (var i = from; i < to; i++) {
          if (v(i) < 0.5 && v(i + 1) >= 0.5) {
            mid = i + (0.5 - v(i)) / (v(i + 1) - v(i));
            break;
          }
        }
        // Pixel centres are at i + 0.5, so the edge sits at mid + 0.5.
        final edge = (mid + 0.5) / dpr;
        // ignore: avoid_print
        print(
          'PROBE composed sigma=$sigma ${vertical ? 'x' : 'y'}-edge at '
          '${edge.toStringAsFixed(2)} (expected ${vertical ? 200 : 350})',
        );
        expect(edge, closeTo(vertical ? 200 : 350, 0.5));
      }
    }
  });

  // Unit of ImageFilter.blur's sigma composed inside the backdrop shader
  // filter: a hard black|white edge at logical x = 200 is blurred and passed
  // through unchanged; the 15.87 % → 84.13 % rise of the edge profile spans
  // 2σ (physical px).
  testWidgets('composed blur sigma unit', (tester) async {
    final program = await ui.FragmentProgram.fromAsset('shaders/probe.frag');
    final shader = program.fragmentShader();
    for (var i = 0; i < 16; i++) {
      shader.setFloat(2 + i, 0);
    }
    shader.setFloat(2 + 12, 1); // uArr[3].x: pass-through

    Future<double> measure(double sigma, bool compose) async {
      final blur = ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
        tileMode: TileMode.clamp,
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: ColoredBox(color: Color(0xFFFFFFFF)),
                ),
                const Positioned(
                  left: 0,
                  top: 0,
                  width: 200,
                  bottom: 0,
                  child: ColoredBox(color: Color(0xFF000000)),
                ),
                Positioned(
                  left: 20,
                  top: 300,
                  width: 360,
                  height: 100,
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: compose
                          ? ui.ImageFilter.compose(
                              outer: ui.ImageFilter.shader(shader),
                              inner: blur,
                            )
                          : blur,
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
      final dpr = tester.view.devicePixelRatio;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: dpr);
      final data = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final row = (350 * dpr).round();
      double v(int x) => data.getUint8((row * image.width + x) * 4) / 255;
      // Linear interpolation of the first crossing of [level].
      double cross(double level) {
        for (var x = (30 * dpr).round(); x < (370 * dpr).round(); x++) {
          final a = v(x), b = v(x + 1);
          if (a < level && b >= level) return x + (level - a) / (b - a);
        }
        return double.nan;
      }

      final sigmaPx = (cross(0.8413) - cross(0.1587)) / 2;
      // ignore: avoid_print
      print(
        'PROBE sigma ${compose ? 'composed' : 'blur-only'}: requested '
        '$sigma logical, measured ${sigmaPx.toStringAsFixed(2)} physical px '
        '= ${(sigmaPx / dpr).toStringAsFixed(2)} logical '
        '(ratio ${(sigmaPx / dpr / sigma).toStringAsFixed(3)}) dpr=$dpr',
      );
      return sigmaPx / dpr;
    }

    for (final sigma in const [2.0, 8.0, 12.0, 20.0]) {
      final blurOnly = await measure(sigma, false);
      final composed = await measure(sigma, true);
      // Same unit with and without the shader; the unit is logical px
      // (a physical-px unit would measure sigma / dpr).
      expect(composed, closeTo(blurOnly, 0.05 * sigma + 0.2));
      expect(composed, closeTo(sigma, 0.15 * sigma + 0.3));
    }
  });
}
