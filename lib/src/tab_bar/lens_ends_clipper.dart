import 'package:flutter/cupertino.dart';

/// The rounded ends of [lens] (one corner radius in from each side): the
/// only part of the lens whose glass refracts the tabs beneath it. Its
/// middle shows the sharp copy on top, and its top and bottom rims refract
/// the bar, as iOS's lens does.
class LensEndsClipper extends CustomClipper<Path> {
  /// Clips to the ends of [lens].
  const LensEndsClipper(this.lens);

  /// The lens capsule's bounds.
  final Rect lens;

  @override
  Path getClip(Size size) {
    final r = lens.height / 2;
    final capsule = Path()
      ..addRRect(RRect.fromRectAndRadius(lens, Radius.circular(r)));
    final ends = Path()
      ..addRect(Rect.fromLTRB(lens.left, lens.top, lens.left + r, lens.bottom))
      ..addRect(
        Rect.fromLTRB(lens.right - r, lens.top, lens.right, lens.bottom),
      );
    return Path.combine(PathOperation.intersect, capsule, ends);
  }

  @override
  bool shouldReclip(LensEndsClipper old) => old.lens != lens;
}
