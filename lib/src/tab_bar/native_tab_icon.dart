import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show IconData;

import 'tab_bar_metrics.dart';

/// Bundled monochrome icon fonts with a known, fixed icon box.
/// Custom fonts retain Flutter rendering, including their font-load lifecycle
/// and any glyph ink extending beyond that box.
bool canRasterizeNativeTabIcon(IconData icon) {
  if (icon.fontFamilyFallback?.isNotEmpty ?? false) return false;
  return (icon.fontFamily == 'MaterialIcons' && icon.fontPackage == null) ||
      (icon.fontFamily == 'CupertinoIcons' &&
          icon.fontPackage == 'cupertino_icons');
}

/// Draws an untinted template for UIKit at the requested display resolution.
/// The transparent logical box matches Flutter's tab icon; UIKit applies its
/// own foreground tint and vibrant material to the alpha mask.
Future<Uint8List> rasterizeNativeTabIcon(
  IconData icon, {
  required double pixelRatio,
  required TextDirection textDirection,
}) async {
  if (!canRasterizeNativeTabIcon(icon)) {
    throw ArgumentError.value(icon, 'icon', 'Requires a bundled icon font');
  }
  if (!pixelRatio.isFinite || pixelRatio <= 0) {
    throw ArgumentError.value(pixelRatio, 'pixelRatio', 'Must be positive');
  }
  const size = TabBarMetrics.iconSize;
  final painter = TextPainter(
    textDirection: textDirection,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        inherit: false,
        color: const Color(0xFFFFFFFF),
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        height: 1,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    ),
  );
  try {
    painter.layout();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    if (icon.matchTextDirection && textDirection == TextDirection.rtl) {
      canvas
        ..translate(size, 0)
        ..scale(-1, 1);
    }
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
    final picture = recorder.endRecording();
    try {
      final pixels = (size * pixelRatio).ceil();
      final image = await picture.toImage(pixels, pixels);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Could not encode tab icon');
        return bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  } finally {
    painter.dispose();
  }
}
