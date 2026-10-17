import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/src/color_picker/color_picker_metrics.dart';
import 'package:adaptive_liquid_glass/src/color_picker/eyedropper.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A [size]-pixel image of [color].
Future<ui.Image> _solid(Color color, {int size = 32}) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(color, BlendMode.src);
  return recorder.endRecording().toImage(size, size);
}

/// The loupe over a page of [page], drawn at 3x; its grey level (red
/// channel) at [dx], [dy] pt from its centre.
Future<int Function(double dx, double dy, [int channel])> _loupe(
  WidgetTester t,
  Color page,
) async {
  final image = (await t.runAsync(() => _solid(page)))!;
  addTearDown(image.dispose);
  final key = GlobalKey();
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: page,
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: EyedropperLoupe(
                image: image,
                pixel: const Offset(16, 16),
                color: page,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final shot = (await t.runAsync(() => boundary.toImage(pixelRatio: 3)))!;
  addTearDown(shot.dispose);
  final bytes = (await t.runAsync(shot.toByteData))!;
  final w = shot.width;
  final c = w / 2;
  return (double dx, double dy, [int channel = 0]) {
    final x = (c + dx * 3).floor();
    final y = (c + dy * 3).floor();
    return Uint8List.view(bytes.buffer)[(y * w + x) * 4 + channel];
  };
}

void main() {
  // UIColorPickerViewController's loupe on iOS 26.4 (simctl recordVideo,
  // held drags; grey levels of the 3x frames).
  testWidgets("over white: UIKit's grey ring, grid and outline", (t) async {
    final at = await _loupe(t, const Color(0xFFFFFFFF));
    // The band of the sampled colour, 62.1-74 pt out.
    expect(at(-67, 0), closeTo(253, 3));
    // The ring, 57.1-62.1 pt: #979797 (measured 151).
    expect(at(-59.6, 0), closeTo(151, 3));
    expect(at(0, 59.6), closeTo(151, 3));
    // The grid line between cells, 1.5 cells out: black at 40% (146).
    expect(
      at(-1.5 * ColorPickerMetrics.loupeCell, 30),
      closeTo(146, 12),
    );
    // A cell: the captured pixel.
    expect(at(-27.5, 27.5), closeTo(253, 3));
    // The centre cell's outline, 4.5-8.5 pt out (measured 151), and the
    // centre pixel inside it.
    expect(at(-6.9, 0), closeTo(151, 3));
    expect(at(0, 0), closeTo(253, 3));
    // The shadow outside the disk: 13% dark at the edge (measured 221),
    // fading over about 30 pt.
    expect(at(-75, 0), closeTo(221, 8));
    expect(at(-100, 0), greaterThan(240));
  });

  testWidgets("over blue: UIKit's white ring and grid", (t) async {
    const blue = Color(0xFF0086FC);
    final at = await _loupe(t, blue);
    // The band is the sampled blue; ring and outline white.
    expect(at(-67, 0, 2), closeTo(252, 3));
    expect(at(-67, 0), closeTo(0, 3));
    expect(at(-59.6, 0), closeTo(255, 3));
    expect(at(-6.9, 0), closeTo(255, 3));
    // The grid: white at 70% over blue (measured red 178).
    expect(
      at(-1.5 * ColorPickerMetrics.loupeCell, 30),
      closeTo(178, 20),
    );
  });

  testWidgets('the ring turns grey between greys 212 and 233', (t) async {
    final dark = await _loupe(t, const Color(0xFFD4D4D4));
    expect(dark(-59.6, 0), closeTo(255, 3));
    final light = await _loupe(t, const Color(0xFFE9E9E9));
    expect(light(-59.6, 0), closeTo(151, 3));
  });

  test('one cell per captured pixel, 148 pt across', () {
    expect(ColorPickerMetrics.loupe, 148);
    // Nine cells span the ring's outer edge (124.2 pt).
    expect(
      ColorPickerMetrics.loupeCell * 9,
      closeTo(2 * (ColorPickerMetrics.loupeRingRadius + 2.5), 0.5),
    );
  });
}
