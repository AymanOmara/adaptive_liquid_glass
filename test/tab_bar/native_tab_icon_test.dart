import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/src/tab_bar/native_tab_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await loader.load();
  });

  Future<({int width, int height, Uint8List rgba})> decode(
    Uint8List png,
  ) async {
    final codec = await ui.instantiateImageCodec(png);
    try {
      final frame = await codec.getNextFrame();
      try {
        final bytes = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        return (
          width: frame.image.width,
          height: frame.image.height,
          rgba: bytes!.buffer.asUint8List(
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          ),
        );
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<Uint8List> raster(IconData icon, [TextDirection? direction]) =>
      rasterizeNativeTabIcon(
        icon,
        pixelRatio: 3,
        textDirection: direction ?? TextDirection.ltr,
      );

  test('only bundled Cupertino and Material fonts are eligible', () {
    expect(canRasterizeNativeTabIcon(CupertinoIcons.house), isTrue);
    expect(
      canRasterizeNativeTabIcon(
        const IconData(0xe88a, fontFamily: 'MaterialIcons'),
      ),
      isTrue,
    );
    for (final icon in [
      const IconData(0x41, fontFamily: 'Custom'),
      const IconData(0x41, fontFamily: 'CupertinoIcons'),
      const IconData(
        0x41,
        fontFamily: 'MaterialIcons',
        fontPackage: 'custom_package',
      ),
      const IconData(
        0x41,
        fontFamily: 'MaterialIcons',
        fontFamilyFallback: ['Custom'],
      ),
    ]) {
      expect(canRasterizeNativeTabIcon(icon), isFalse);
    }
  });

  test(
    'real glyph PNG is white on transparency at the requested DPR',
    () async {
      final png = await raster(CupertinoIcons.house);
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      final pixels = await decode(png);
      expect((pixels.width, pixels.height), (84, 84));
      var ink = 0;
      var transparent = 0;
      for (var i = 0; i < pixels.rgba.length; i += 4) {
        if (pixels.rgba[i + 3] == 0) {
          transparent++;
        } else {
          ink++;
          expect(pixels.rgba.sublist(i, i + 3), [255, 255, 255]);
        }
      }
      expect(ink, greaterThan(0));
      expect(transparent, greaterThan(0));
    },
  );

  test('selected artwork retains its distinct glyph', () async {
    final normal = await decode(await raster(CupertinoIcons.house));
    final selected = await decode(await raster(CupertinoIcons.house_fill));
    expect(selected.rgba, isNot(orderedEquals(normal.rgba)));
  });

  testWidgets('template retains the rendered Flutter Icon alignment', (
    t,
  ) async {
    final key = GlobalKey();
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: const Icon(
              CupertinoIcons.house,
              size: 28,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final rendered = await decode(bytes!.buffer.asUint8List());
        final template = await decode(await raster(CupertinoIcons.house));
        expect(
          (template.width, template.height),
          (rendered.width, rendered.height),
        );
        expect(template.rgba, orderedEquals(rendered.rgba));
      } finally {
        image.dispose();
      }
    });
  });

  test(
    'directional glyph mirrors, nondirectional artwork stays identical',
    () async {
      final ltr = await decode(await raster(CupertinoIcons.back));
      final rtl = await decode(
        await raster(CupertinoIcons.back, TextDirection.rtl),
      );
      expect(rtl.rgba, isNot(orderedEquals(ltr.rgba)));
      // Mirrored paths can differ slightly at antialiased edges, and by how
      // much depends on the rasteriser (macOS stays within 2, Linux CI 3):
      // bound the worst edge pixel loosely and the average tightly. An
      // unmirrored glyph differs by ~255 over its whole stroke.
      var worst = 0;
      var total = 0;
      for (var y = 0; y < ltr.height; y++) {
        for (var x = 0; x < ltr.width; x++) {
          final from = (y * ltr.width + x) * 4;
          final to = (y * ltr.width + ltr.width - 1 - x) * 4;
          final d = (rtl.rgba[to + 3] - ltr.rgba[from + 3]).abs();
          total += d;
          if (d > worst) worst = d;
        }
      }
      expect(worst, lessThanOrEqualTo(16));
      expect(total / (ltr.width * ltr.height), lessThan(0.5));
      final normal = await raster(CupertinoIcons.house);
      final reversed = await raster(CupertinoIcons.house, TextDirection.rtl);
      expect(reversed, orderedEquals(normal));
    },
  );

  test('rejects custom fonts and invalid display scales', () async {
    await expectLater(
      raster(const IconData(0x41, fontFamily: 'Custom')),
      throwsArgumentError,
    );
    for (final ratio in [0.0, -1.0, double.nan, double.infinity]) {
      await expectLater(
        rasterizeNativeTabIcon(
          CupertinoIcons.house,
          pixelRatio: ratio,
          textDirection: TextDirection.ltr,
        ),
        throwsArgumentError,
      );
    }
  });
}
