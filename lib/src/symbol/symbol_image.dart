import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A system symbol rendered by UIKit: white on transparent, with UIKit's
/// alignment rect (the part a tab bar centres).
@immutable
class SymbolImage {
  /// A rendered symbol.
  const SymbolImage({
    required this.image,
    required this.size,
    required this.alignment,
  });

  /// The symbol, at the screen's scale.
  final ui.Image image;

  /// Its size in logical pixels.
  final Size size;

  /// UIKit's alignment rect within [size].
  final Rect alignment;

  static const MethodChannel _channel = MethodChannel('adaptive_liquid_glass');
  static final Map<String, Future<SymbolImage?>> _cache = {};

  /// Renders [name] (an SF Symbol) at [pointSize] and [weight] (UIKit's
  /// names: regular, semibold, …) and [scale] (small, medium, large), once
  /// per combination; null off iOS or for an unknown symbol.
  static Future<SymbolImage?> load(
    String name, {
    required double pointSize,
    required String weight,
    required String scale,
    required double devicePixelRatio,
  }) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return SynchronousFuture(null);
    }
    final key = '$name|$pointSize|$weight|$scale|$devicePixelRatio';
    return _cache[key] ??= _render(
      name,
      pointSize,
      weight,
      scale,
      devicePixelRatio,
    );
  }

  static Future<SymbolImage?> _render(
    String name,
    double pointSize,
    String weight,
    String scale,
    double dpr,
  ) async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>('symbol', {
        'name': name,
        'pointSize': pointSize,
        'weight': weight,
        'scale': scale,
        'scale_px': dpr,
      });
      if (r == null) return null;
      final codec = await ui.instantiateImageCodec(r['png']! as Uint8List);
      final frame = await codec.getNextFrame();
      double n(String k) => (r[k]! as num).toDouble();
      final size = Size(n('width'), n('height'));
      return SymbolImage(
        image: frame.image,
        size: size,
        alignment: Rect.fromLTRB(
          n('alignLeft'),
          n('alignTop'),
          size.width - n('alignRight'),
          size.height - n('alignBottom'),
        ),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
