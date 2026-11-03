import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/src/color_picker/app_capture.dart';
import 'package:adaptive_liquid_glass/src/color_picker/eyedropper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SurfaceView capture preserves Flutter and native overlay alpha', (
    t,
  ) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    const hook = MethodChannel('example/capture_test');
    final background = ValueNotifier(const Color(0xFFFF0000));
    addTearDown(background.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<Color>(
          valueListenable: background,
          builder: (_, color, _) => ColoredBox(
            color: color,
            child: const Stack(
              children: [
                Positioned(
                  left: 20,
                  top: 130,
                  width: 150,
                  height: 100,
                  child: ColoredBox(color: Color(0xFF0000FF)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    Future<void> settle() async {
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    }

    try {
      await hook.invokeMethod<void>('overlay');
      await settle();
      Future<void> verifyPoints(Map<Offset, Color> points) async {
        // A resize can invalidate a PixelCopy snapshot while the compositor
        // settles. Require eventual accurate pixels, not a stale frame.
        AppCapture? capture;
        for (var attempt = 0; attempt < 5 && capture == null; attempt++) {
          capture = await t.runAsync<AppCapture?>(() => captureAppView(t.view));
          if (capture == null) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await t.pump();
          }
        }
        if (capture == null) {
          final raw = await t.runAsync(
            () =>
                const MethodChannel('adaptive_liquid_glass')
                    .invokeMapMethod<String, Object?>('captureApp'),
          );
          final geometry = await hook.invokeMethod<Object>('geometry');
          debugPrint(
            'Capture rejected: raw ${raw?['width']}x${raw?['height']} scale ${raw?['scale']}; Dart ${t.view.physicalSize} @ ${t.view.devicePixelRatio}; geometry $geometry',
          );
        }
        expect(capture, isNotNull);
        try {
          final data = (await t.runAsync(
            () => capture!.image.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba,
            ),
          ))!;
          Color at(Offset point) => colorAtPixel(
            data,
            capture!.image.width,
            capture.image.height,
            point * capture.ratio,
          );
          for (final point in points.entries) {
            if (at(point.key) != point.value) {
              var minX = capture!.image.width;
              var minY = capture.image.height;
              var maxX = -1;
              var maxY = -1;
              for (var y = 0; y < capture.image.height; y += 3) {
                for (var x = 0; x < capture.image.width; x += 3) {
                  if (data.getUint32((y * capture.image.width + x) * 4) ==
                      0x0000FFFF) {
                    if (x < minX) minX = x;
                    if (y < minY) minY = y;
                    if (x > maxX) maxX = x;
                    if (y > maxY) maxY = y;
                  }
                }
              }
              debugPrint(
                'Blue bounds ${Rect.fromLTRB(minX / capture.ratio, minY / capture.ratio, maxX / capture.ratio, maxY / capture.ratio)}; offset ${capture.offset}; Dart ${t.view.physicalSize} @ ${t.view.devicePixelRatio}',
              );
            }
            expect(at(point.key), point.value, reason: 'pixel at ${point.key}');
          }
        } finally {
          capture?.image.dispose();
        }
      }

      Future<void> verify(
        Color page,
        Color overlay, {
        Color blue = const Color(0xFF0000FF),
      }) => verifyPoints({
        const Offset(200, 250): page,
        const Offset(80, 180): blue,
        const Offset(80, 350): overlay,
      });

      Future<void> pickAt(Offset nativePoint, double left) async {
        final point = Offset(nativePoint.dx - left, nativePoint.dy - 80);
        final picking = pickColorFromApp(
          t.element(find.byType(ValueListenableBuilder<Color>)),
        );
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
        await t.tapAt(point);
        await t.pump();
        // The native overlay is absent from a Flutter-only fallback image.
        expect(await picking, const Color(0xFF7F8000));
      }

      // 50% native green over Flutter's opaque red.
      await verify(const Color(0xFFFF0000), const Color(0xFF7F8000));
      await hook.invokeMethod<void>('surfaceOnTop', true);
      await settle();
      final sdk = (await hook.invokeMethod<int>('sdk'))!;
      if (sdk >= 36) {
        // Flutter is above the entire window, so its red must cover the
        // native green overlay. Composing in the old order gives yellow.
        await verify(const Color(0xFFFF0000), const Color(0xFFFF0000));
      } else {
        // Older platforms cannot reliably identify the surface order.
        expect(await t.runAsync(() => captureAppView(t.view)), isNull);
      }
      await hook.invokeMethod<void>('surfaceOnTop', false);
      await settle();
      await verify(const Color(0xFFFF0000), const Color(0xFF7F8000));
      await hook.invokeMethod<void>('coverWindow');
      await settle();
      if (sdk >= 36) {
        // A completely covered lower surface has no transparent hole. Its
        // explicit order still permits the correct, entirely green capture.
        await verify(
          const Color(0xFF00FF00),
          const Color(0xFF00FF00),
          blue: const Color(0xFF00FF00),
        );
      } else {
        expect(await t.runAsync(() => captureAppView(t.view)), isNull);
      }
      await hook.invokeMethod<void>('overlay');
      await settle();
      await hook.invokeMethod<void>('surfaceGeometry', {
        'left': 40,
        'resize': false,
      });
      await t.pump();
      await settle();
      if (sdk >= 36) {
        await verifyPoints({
          const Offset(10, 450): const Color(
            0xFFFF00FF,
          ), // Native background outside the surface.
          const Offset(200, 450): const Color(0xFFFF0000),
          const Offset(80, 350): const Color(0xFF7F8000),
          const Offset(80, 250): const Color(0xFF0000FF),
        });
        await pickAt(const Offset(80, 350), 40);
        await hook.invokeMethod<void>('surfaceOnTop', true);
        await settle();
        await verifyPoints({
          const Offset(10, 450): const Color(0xFFFF00FF),
          const Offset(200, 450): const Color(0xFFFF0000),
          const Offset(80, 350): const Color(0xFFFF0000),
          const Offset(80, 250): const Color(0xFF0000FF),
        });
        await hook.invokeMethod<void>('surfaceOnTop', false);
        await hook.invokeMethod<void>('surfaceGeometry', {
          'left': -40,
          'resize': false,
        });
        await t.pump();
        await settle();
        await verifyPoints({
          Offset(t.view.physicalSize.width / t.view.devicePixelRatio - 10, 500):
              const Color(0xFFFF00FF),
          const Offset(10, 450): const Color(
            0xFFFF0000,
          ), // Surface clipped at the parent's left edge.
          const Offset(80, 350): const Color(0xFF7F8000),
          const Offset(20, 250): const Color(0xFF0000FF),
        });
        await pickAt(const Offset(80, 350), -40);
        // The same surface inside a plain native container. The container
        // contributes its own offset and clips at x=12, not FlutterView's x=0.
        await hook.invokeMethod<void>('surfaceGeometry', {
          'left': -40,
          'resize': false,
          'nested': true,
        });
        await t.pump();
        await settle();
        await verifyPoints({
          const Offset(5, 450): const Color(0xFFFF00FF),
          const Offset(20, 450): const Color(0xFFFF0000),
          const Offset(80, 350): const Color(0xFF7F8000),
          const Offset(20, 250): const Color(0xFF0000FF),
        });
        await pickAt(const Offset(80, 350), -40);
        await hook.invokeMethod<void>('surfaceOnTop', true);
        await settle();
        await verifyPoints({
          const Offset(5, 450): const Color(0xFFFF00FF),
          const Offset(20, 450): const Color(0xFFFF0000),
          const Offset(80, 350): const Color(0xFFFF0000),
          const Offset(20, 250): const Color(0xFF0000FF),
        });
        await hook.invokeMethod<void>('surfaceOnTop', false);
      } else {
        expect(await t.runAsync(() => captureAppView(t.view)), isNull);
      }
      if (sdk >= 36) {
        // Scaling is outside the native capture contract; never return
        // incorrectly mapped pixels for an unsupported ancestor transform.
        await hook.invokeMethod<void>('containerTransform', true);
        await settle();
        expect(await t.runAsync(() => captureAppView(t.view)), isNull);
        await hook.invokeMethod<void>('containerTransform', false);
      }
      await hook.invokeMethod<void>('surfaceGeometry');
      await t.pump();
      await settle();
      await verify(const Color(0xFFFF0000), const Color(0xFF7F8000));
      // Exercise the engine's image composition path as well, with fresh
      // Flutter pixels so an accidentally stale SurfaceView copy cannot pass.
      await hook.invokeMethod<void>('imageComposition', true);
      background.value = const Color(0xFF00FFFF);
      await t.pump();
      await settle();
      var acquired = false;
      for (var i = 0; i < 5 && !acquired; i++) {
        acquired = await hook.invokeMethod<bool>('imageFrame') ?? false;
        if (!acquired) await settle();
      }
      expect(acquired, true);
      await settle();
      await verify(const Color(0xFF00FFFF), const Color(0xFF00FF7F));
    } finally {
      await hook.invokeMethod<void>('surfaceGeometry');
      await hook.invokeMethod<void>('imageComposition', false);
      await hook.invokeMethod<void>('surfaceOnTop', false);
      await hook.invokeMethod<void>('clear');
    }
  });
}
