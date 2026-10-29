import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A capture of a Flutter view, including native subviews when supported.
class AppCapture {
  /// The decoded image and its mapping from Flutter logical coordinates.
  const AppCapture({
    required this.image,
    required this.ratio,
    this.offset = ui.Offset.zero,
  });

  /// The captured pixels; the caller owns and disposes this image.
  final ui.Image image;

  /// Physical pixels per Flutter logical pixel.
  final double ratio;

  /// The render surface's offset within the captured view, in logical pixels.
  /// A Flutter global point maps to `(point + offset) * ratio` in [image].
  final ui.Offset offset;
}

/// Returns null when native capture is unavailable, so the caller can use
/// Flutter's repaint-boundary capture. The image starts at Flutter's view
/// origin; it excludes other apps and separate system/protected surfaces.
Future<AppCapture?> captureAppView(ui.FlutterView view) async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.android)) {
    return null;
  }
  try {
    final response = await const MethodChannel(
      'adaptive_liquid_glass',
    ).invokeMapMethod<String, Object?>('captureApp');
    final png = response?['png'];
    final scale = response?['scale'];
    final dx = response?['flutterOffsetX'] ?? 0;
    final dy = response?['flutterOffsetY'] ?? 0;
    if (png is! Uint8List ||
        scale is! num ||
        !scale.isFinite ||
        scale <= 0 ||
        dx is! num ||
        !dx.isFinite ||
        dy is! num ||
        !dy.isFinite) {
      return null;
    }
    final codec = await ui.instantiateImageCodec(png);
    ui.Image image;
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
    // Reject a stale orientation, resized window or a different Flutter view.
    // A native capture must match this view's current physical dimensions.
    if ((image.width - view.physicalSize.width).abs() > 1 ||
        (image.height - view.physicalSize.height).abs() > 1 ||
        (scale.toDouble() - view.devicePixelRatio).abs() > 0.001) {
      image.dispose();
      return null;
    }
    return AppCapture(
      image: image,
      ratio: scale.toDouble(),
      offset: ui.Offset(dx.toDouble(), dy.toDouble()),
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  } on Exception {
    // A failed or unsupported native image decode falls back to Flutter.
    return null;
  }
}
