import 'package:flutter/widgets.dart';

import 'symbol_image.dart';

/// An SF Symbol drawn by the system on iOS, in the ambient [IconTheme]'s
/// colour, centred on its alignment rect as UIKit's tab bar does. Elsewhere
/// (and until it is ready) it shows [fallback].
///
/// The symbol artwork is never bundled: iOS renders it at run time.
class GlassSymbol extends StatelessWidget {
  /// The symbol [name], or [fallback] where it cannot be drawn.
  const GlassSymbol(
    this.name, {
    super.key,
    required this.fallback,
    this.pointSize,
    this.weight = 'regular',
    this.scale = 'medium',
  });

  /// The SF Symbol's name, e.g. `house.fill`.
  final String name;

  /// Shown off iOS, for an unknown symbol and while the symbol loads.
  final IconData fallback;

  /// The symbol's point size; null uses the [IconTheme]'s size.
  final double? pointSize;

  /// UIKit's symbol weight name (`regular`, `medium`, `semibold`, …).
  final String weight;

  /// UIKit's symbol scale name (`small`, `medium`, `large`).
  final String scale;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final box = theme.size ?? 24;
    final future = SymbolImage.load(
      name,
      pointSize: pointSize ?? box,
      weight: weight,
      scale: scale,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    return FutureBuilder<SymbolImage?>(
      future: future,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) return Icon(fallback);
        final shift = Offset(box / 2, box / 2) - s.alignment.center;
        return SizedBox.square(
          dimension: box,
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: shift,
              child: RawImage(
                image: s.image,
                width: s.size.width,
                height: s.size.height,
                color: theme.color,
                colorBlendMode: BlendMode.srcIn,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        );
      },
    );
  }
}
