import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Blurs and fades the icon of a [GlassButton.icon] below it, leaving
/// its glass alone (the search close button's hide, where SwiftUI blurs
/// the glyph out while the glass merges away). Internal.
class GlassButtonGlyphEffect extends InheritedWidget {
  /// Blurs [child]'s button glyphs by [blur] and fades them to [opacity].
  const GlassButtonGlyphEffect({
    super.key,
    this.blur = 0,
    this.opacity = 1,
    this.scale = 1,
    required super.child,
  });

  /// The blur's sigma, in logical pixels.
  final double blur;

  /// The glyph's opacity, 0 to 1.
  final double opacity;

  /// The glyph's scale about its centre.
  final double scale;

  /// Applies the nearest effect to [glyph], or returns it as is.
  static Widget wrap(BuildContext context, Widget glyph) {
    final e = context
        .dependOnInheritedWidgetOfExactType<GlassButtonGlyphEffect>();
    if (e == null) return glyph;
    var w = glyph;
    if (e.scale != 1) w = Transform.scale(scale: e.scale, child: w);
    if (e.blur > 0) {
      w = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: e.blur,
          sigmaY: e.blur,
          tileMode: TileMode.decal,
        ),
        child: w,
      );
    }
    return e.opacity < 1 ? Opacity(opacity: e.opacity, child: w) : w;
  }

  @override
  bool updateShouldNotify(GlassButtonGlyphEffect old) =>
      blur != old.blur || opacity != old.opacity || scale != old.scale;
}
