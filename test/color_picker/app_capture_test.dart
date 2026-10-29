import 'dart:ui' as ui;

import 'package:adaptive_liquid_glass/src/color_picker/app_capture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('adaptive_liquid_glass');
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<Uint8List> png() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFFFF0000), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(2, 2);
    try {
      return (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  testWidgets('decodes native image with the view scale and pixel origin', (
    t,
  ) async {
    t.view.physicalSize = const ui.Size(2, 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final bytes = (await t.runAsync(png))!;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'captureApp');
      return {'png': bytes, 'scale': 2.0};
    });
    final capture = await t.runAsync(() => captureAppView(t.view));
    expect(capture, isNotNull);
    expect(capture!.ratio, 2);
    expect(capture.offset, ui.Offset.zero);
    expect(capture.image.width, 2);
    final pixels = (await t.runAsync(
      () =>
          capture.image.toByteData(format: ui.ImageByteFormat.rawStraightRgba),
    ))!;
    expect(pixels.getUint32(0), 0xFF0000FF);
    capture.image.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('preserves positive and negative surface offsets', (t) async {
    t.view.physicalSize = const ui.Size(2, 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final bytes = (await t.runAsync(png))!;
    for (final dx in [-40.0, 40.0]) {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'png': bytes,
          'scale': 2.0,
          'flutterOffsetX': dx,
          'flutterOffsetY': 80,
        },
      );
      final capture = await t.runAsync(() => captureAppView(t.view));
      expect(capture!.offset, ui.Offset(dx, 80));
      capture.image.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('rejects invalid coordinate offsets', (t) async {
    t.view.physicalSize = const ui.Size(2, 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
    final bytes = (await t.runAsync(png))!;
    for (final offset in [double.nan, double.infinity, '40']) {
      for (final key in ['flutterOffsetX', 'flutterOffsetY']) {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => {'png': bytes, 'scale': 2.0, key: offset},
        );
        expect(await t.runAsync(() => captureAppView(t.view)), isNull);
      }
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('rejects stale window dimensions and scale', (t) async {
    t.view.physicalSize = const ui.Size(3, 2);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final bytes = (await t.runAsync(png))!;
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'png': bytes, 'scale': 1.0},
    );
    // More than one physical pixel avoids rejecting harmless raster rounding.
    t.view.physicalSize = const ui.Size(5, 2);
    expect(await t.runAsync(() => captureAppView(t.view)), isNull);
    t.view.physicalSize = const ui.Size(2, 2);
    t.view.devicePixelRatio = 2;
    expect(await t.runAsync(() => captureAppView(t.view)), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('missing native capture falls back without an error', (t) async {
    expect(await t.runAsync(() => captureAppView(t.view)), isNull);
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await t.runAsync(() => captureAppView(t.view)), isNull);
    messenger.setMockMethodCallHandler(channel, (_) async => {'scale': 0});
    expect(await t.runAsync(() => captureAppView(t.view)), isNull);
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'png': Uint8List.fromList([1, 2, 3]),
        'scale': 1.0,
      },
    );
    expect(await t.runAsync(() => captureAppView(t.view)), isNull);
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'png': Uint8List(0), 'scale': double.infinity},
    );
    expect(await t.runAsync(() => captureAppView(t.view)), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
