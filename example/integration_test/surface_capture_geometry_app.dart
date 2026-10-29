// Normal-app geometry probe: avoids the integration harness's view configuration.
import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/src/color_picker/app_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: ColoredBox(
        color: Color(0xFFFF0000),
        child: Stack(
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
  );
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    const hook = MethodChannel('example/capture_test');
    await Future<void>.delayed(const Duration(seconds: 1));
    await hook.invokeMethod<void>('overlay');
    await hook.invokeMethod<void>('surfaceGeometry', {
      'left': 40,
      'resize': const bool.fromEnvironment('RESIZE_SURFACE'),
    });
    for (final renderView in WidgetsBinding.instance.renderViews) {
      renderView.markNeedsPaint();
    }
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(seconds: 1));
    final view = ui.PlatformDispatcher.instance.views.single;
    final capture = await captureAppView(view);
    debugPrint(
      'GEOMETRY view ${view.physicalSize} DPR ${view.devicePixelRatio} native ${await hook.invokeMethod<Object>('geometry')}',
    );
    if (capture == null) {
      debugPrint('GEOMETRY capture missing');
      return;
    }
    try {
      final data = (await capture.image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      var minX = capture.image.width,
          minY = capture.image.height,
          maxX = -1,
          maxY = -1;
      for (var y = 0; y < capture.image.height; y += 3) {
        for (var x = 0; x < capture.image.width; x += 3) {
          if (data.getUint32((y * capture.image.width + x) * 4) == 0x0000FFFF) {
            if (x < minX) minX = x;
            if (y < minY) minY = y;
            if (x > maxX) maxX = x;
            if (y > maxY) maxY = y;
          }
        }
      }
      debugPrint(
        'GEOMETRY blue ${Rect.fromLTRB(minX / capture.ratio, minY / capture.ratio, maxX / capture.ratio, maxY / capture.ratio)} offset ${capture.offset}',
      );
    } finally {
      capture.image.dispose();
    }
  });
}
