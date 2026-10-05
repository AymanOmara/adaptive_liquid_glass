import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// How dark the refraction band at one end of the lens is, from how far
/// [inside] the bar that end is (points; negative is past the bar's edge).
///
/// iOS's lens refracts what lies just outside its edge into a band inside
/// it: past the bar that is the dark page, well inside the bar it is the
/// bar itself (no visible band). The glass reaches a few points past its
/// edge, so an end up to 2 pt inside the bar still shows the outside fully
/// (as on iOS at the end tabs); the band is gone 8 pt in.
double lensEndShade({required double inside}) =>
    (1 - (inside - 2) / 6).clamp(0.0, 1.0);

/// The rim of iOS 26's tab bar lens, measured from iOS 26.4 (Kept) while
/// held: a 1-px bright rim (≈135 at the top, ≈95 at the bottom), a teal
/// fringe, then a ~4-pt band of the refracted outside — about 40 % darker
/// 4–8 pt below the top, near black 3.5–7.5 pt above the bottom and at an
/// end past the bar, nothing at an end over the bar.
///
/// SwiftUI's public clear glass draws only a faint rim, so this layer is
/// painted over it. Everything scales with [strength] (how far the lens has
/// grown); the fringe grows with [motion] (0 at rest, 1 moving fast).
class LensRimPainter extends CustomPainter {
  /// Creates the painter.
  const LensRimPainter({
    required this.strength,
    required this.leftShade,
    required this.rightShade,
    this.motion = 0,
  });

  /// 0 (no lens) to 1 (fully grown).
  final double strength;

  /// Dark band at the left and right ends; see [lensEndShade].
  final double leftShade;

  /// See [leftShade].
  final double rightShade;

  /// 0 at rest to 1 moving fast.
  final double motion;

  static const double _topBand = 0.38;
  static const double _bottomBand = 0.95;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final s = strength.clamp(0.0, 1.0);
    final box = Offset.zero & size;
    final r = size.height / 2;
    RRect rr(double inset) => RRect.fromRectAndRadius(
      box.deflate(inset),
      Radius.circular(math.max(r - inset, 0)),
    );
    const black = Color(0xFF000000);

    // The refracted outside: a band 4 pt wide, its centre 5.5 pt in,
    // lighter under the top (page content) than above the bottom.
    canvas.saveLayer(box, Paint());
    canvas.drawRRect(
      rr(5.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            black.withValues(alpha: _topBand * s),
            black.withValues(alpha: _bottomBand * s),
          ],
        ).createShader(box),
    );
    final fringe = (0.5 + 0.5 * motion.clamp(0.0, 1.0)) * s;
    canvas.drawRRect(
      rr(2.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF14A0B4).withValues(alpha: 0.35 * fringe),
    );
    _mask(canvas, size, r);
    canvas.restore();

    // Bright rim, brighter at the top.
    canvas.drawRRect(
      rr(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.42 * s),
            const Color(0xFFFFFFFF).withValues(alpha: 0.2 * s),
          ],
        ).createShader(box),
    );
  }

  /// Keeps the band along the straight top and bottom (where the lens
  /// overhangs the bar) and across each rounded end by that end's shade.
  void _mask(Canvas canvas, Size size, double r) {
    const solid = Color(0xFF000000);
    canvas.drawRect(
      Rect.fromLTRB(r, 0, size.width - r, size.height),
      Paint()
        ..blendMode = BlendMode.dstIn
        ..color = solid,
    );
    void cap(Rect rect, double shade, bool left) => canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          colors: left
              ? [solid.withValues(alpha: shade), solid]
              : [solid, solid.withValues(alpha: shade)],
        ).createShader(rect),
    );
    cap(Rect.fromLTRB(0, 0, r, size.height), leftShade, true);
    cap(
      Rect.fromLTRB(size.width - r, 0, size.width, size.height),
      rightShade,
      false,
    );
  }

  @override
  bool shouldRepaint(LensRimPainter old) =>
      old.strength != strength ||
      old.leftShade != leftShade ||
      old.rightShade != rightShade ||
      old.motion != motion;
}
