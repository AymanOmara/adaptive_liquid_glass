import 'package:flutter/cupertino.dart';

/// iOS 26's badge. The capsule (height, padding, text) is measured from
/// SwiftUI `TabView`'s `.badge(3)`, `.badge(42)` and `.badge("New")`
/// (iOS 26.4: a 20-pt capsule, 12-pt semibold numerals, the capsule 9.7 pt
/// wider than its ink); the dot and the offsets on a plain child are
/// ESTIMATED from UIKit and the HIG. The tab bar draws its count badges with
/// these too.
abstract final class BadgeMetrics {
  /// A text badge's height (and least width).
  static const double height = 20;

  /// A dot badge's diameter.
  static const double dot = 10;

  /// A text badge's horizontal padding.
  static const double horizontalPadding = 4;

  /// A text badge's font size.
  static const double fontSize = 12;

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
    fontWeight: FontWeight.w600,
    height: 1,
  );
}
