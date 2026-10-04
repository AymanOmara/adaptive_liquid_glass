import 'dart:convert';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/services.dart';

/// One glass shape of a fidelity scene, in logical points from the screen's
/// top-left.
class SceneShape {
  /// Parses a shape entry of `tool/scenes/scenes.json`.
  SceneShape.fromJson(Map<String, Object?> j)
    : rect = Rect.fromLTWH(
        (j['x']! as num).toDouble(),
        (j['y']! as num).toDouble(),
        (j['w']! as num).toDouble(),
        (j['h']! as num).toDouble(),
      ),
      shape = switch (j['shape']) {
        'circle' => const GlassShape.circle(),
        'rect' => GlassShape.rect((j['radius']! as num).toDouble()),
        _ => const GlassShape.capsule(),
      },
      glass = _glass(j['variant'] as String?, j['tint'] as String?);

  /// Bounds in logical points.
  final Rect rect;

  /// Outline of the glass.
  final GlassShape shape;

  /// Variant and tint.
  final Glass glass;

  static Glass _glass(String? variant, String? tint) {
    final base = variant == 'clear' ? Glass.clear : Glass.regular;
    if (tint == null) return base;
    final v = int.parse(tint.substring(1), radix: 16); // RRGGBBAA
    return base.tint(Color(((v & 0xFF) << 24) | (v >> 8)));
  }
}

/// A static fidelity scene: a background, a brightness and glass shapes.
class Scene {
  /// Parses a scene entry of `tool/scenes/scenes.json`.
  Scene.fromJson(Map<String, Object?> j)
    : id = j['id']! as String,
      background = j['background']! as String,
      brightness = j['brightness'] == 'dark'
          ? Brightness.dark
          : Brightness.light,
      spacing = (j['spacing'] as num?)?.toDouble(),
      shapes = [
        for (final s in j['shapes']! as List<Object?>)
          SceneShape.fromJson((s! as Map).cast<String, Object?>()),
      ];

  /// Scene id, used in launch arguments and screenshot names.
  final String id;

  /// Background asset name under `assets/backgrounds/`.
  final String background;

  /// Platform brightness the scene renders in.
  final Brightness brightness;

  /// Non-null: all shapes share one `GlassGroup` with this spacing.
  final double? spacing;

  /// Glass shapes, in paint order.
  final List<SceneShape> shapes;

  /// Loads every scene from `assets/scenes.json`, keyed by id.
  static Future<Map<String, Scene>> loadAll() async {
    final j = jsonDecode(
      await rootBundle.loadString('assets/scenes.json'),
    ) as Map<String, Object?>;
    return {
      for (final s
          in (j['scenes']! as List<Object?>).cast<Map<Object?, Object?>>())
        s['id']! as String: Scene.fromJson(s.cast<String, Object?>()),
    };
  }
}
