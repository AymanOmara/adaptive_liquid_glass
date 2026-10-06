import 'package:flutter/cupertino.dart';

/// Clips everything above [top] (the status bar).
class ClipBelow extends CustomClipper<Rect> {
  /// Clips above [top].
  const ClipBelow(this.top);

  /// The status bar's height.
  final double top;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, top, size.width * 2, size.height * 4);

  @override
  bool shouldReclip(ClipBelow old) => old.top != top;
}
