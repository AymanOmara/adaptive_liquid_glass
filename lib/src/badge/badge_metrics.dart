import 'package:flutter/cupertino.dart';

/// iOS 26's badge, ESTIMATED from UIKit and the HIG's defaults; the values
/// are not measured. The tab bar draws its badges with these too.
abstract final class BadgeMetrics {
  /// A text badge's height (and least width).
  static const double height = 18;

  /// A dot badge's diameter.
  static const double dot = 10;

  /// A text badge's horizontal padding.
  static const double horizontalPadding = 5;

  /// A text badge's font size.
  static const double fontSize = 13;

  /// How far a text badge rises above the child's top.
  static const double textOffsetTop = 6;

  /// How far a text badge overhangs the child's end.
  static const double textOffsetEnd = 8;

  /// How far a dot badge rises above the child's top.
  static const double dotOffsetTop = 1;

  /// How far a dot badge overhangs the child's end.
  static const double dotOffsetEnd = 1;

  /// A text badge's text.
  static const TextStyle text = TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    height: 1,
  );
}
