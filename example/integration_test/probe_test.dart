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
}
