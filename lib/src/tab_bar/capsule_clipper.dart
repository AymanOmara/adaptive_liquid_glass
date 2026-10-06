import 'package:flutter/cupertino.dart';

/// Just [capsule].
class CapsuleClipper extends CustomClipper<Path> {
  /// Clips to [capsule].
  const CapsuleClipper(this.capsule);

  /// The capsule's bounds; its corner radius is half its height.
  final Rect capsule;

  @override
  Path getClip(Size size) => Path()
    ..addRRect(
      RRect.fromRectAndRadius(capsule, Radius.circular(capsule.height / 2)),
    );

  @override
  bool shouldReclip(CapsuleClipper old) => old.capsule != capsule;
}
