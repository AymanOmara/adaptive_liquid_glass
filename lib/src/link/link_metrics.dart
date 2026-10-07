import 'package:flutter/cupertino.dart';

/// Defaults shared by `GlassLink` and `GlassShareLink`. Both are glass
/// buttons, so their geometry comes from `GlassButtonMetrics`; only the
/// glyphs and the label weight live here. The values are ESTIMATED from
/// SwiftUI's `Link` and `ShareLink` with `.buttonStyle(.glass)` on iOS 26,
/// not measured.
abstract final class LinkMetrics {
  /// The link's default leading glyph: SF Symbols' `arrow.up.right`.
  static const IconData linkIcon = CupertinoIcons.arrow_up_right;

  /// The share link's default glyph: SF Symbols' `square.and.arrow.up`.
  static const IconData shareIcon = CupertinoIcons.share;

  /// The label's weight (SwiftUI uses the body weight for both).
  static const FontWeight labelWeight = FontWeight.w400;
}
