import 'package:flutter/cupertino.dart';

/// Everything but [hole] (a capsule); everything when it is null.
class HoleClipper extends CustomClipper<Path> {
  /// Clips out [hole].
  const HoleClipper(this.hole);

  /// The capsule cut out of the clip, or null for none.
  final Rect? hole;

  @override
  Path getClip(Size size) {
    final all = Path()..addRect(Offset.zero & size);
    final hole = this.hole;
    if (hole == null) return all;
    return Path.combine(
      PathOperation.difference,
      all,
      Path()..addRRect(
        RRect.fromRectAndRadius(hole, Radius.circular(hole.height / 2)),
      ),
    );
  }

  @override
  bool shouldReclip(HoleClipper old) => old.hole != hole;
}
