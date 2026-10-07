import 'package:flutter/painting.dart' show FontWeight;

import '../button/glass_control_size.dart';

/// iOS 26's empty state, measured from SwiftUI's `ContentUnavailableView`
/// (iOS 26.4, iPhone 17 Pro at 3x; `tool/reference/side_by_side.sh
/// emptystate`) unless a value says estimated. The gaps are fitted so the
/// glyphs land where SwiftUI's do, as SF Symbols and CupertinoIcons draw
/// differently inside their boxes.
abstract final class EmptyStateMetrics {
  /// The column's horizontal inset, keeping centred text readable
  /// (estimated).
  static const double horizontalPadding = 32;

  /// The icon's size (measured: the tray and magnifier glyphs as wide as
  /// SwiftUI's).
  static const double iconSize = 56;

  /// The icon's box to the title's (fitted: 23 pt from the glyph's bottom
  /// to the title's cap top).
  static const double iconGap = 12.33;

  /// The title's text size (fitted to the glyphs' width and height).
  static const double titleSize = 21;

  /// The title's font weight.
  static const FontWeight titleWeight = FontWeight.w800;

  /// The description's gap to the title (fitted: cap tops 30.33 apart).
  static const double descriptionGap = 5.67;

  /// The description's text size (measured: iOS .subheadline).
  static const double descriptionSize = 15;

  /// The actions' gap to the description (fitted: 45 pt from the
  /// description's cap top to the button label's).
  static const double actionsGap = 20.33;

  /// Space SwiftUI keeps below the block, lifting it above a plain
  /// centring (measured: a centred column sat 13.33 pt low without actions,
  /// so the block is 26.67 pt taller than its content).
  static const double bottomInset = 26.67;

  /// [bottomInset] when the block has actions (measured: 2.67 pt low with
  /// one small glass action).
  static const double actionsBottomInset = 5.33;

  /// The `.search` variant's icon gap: SwiftUI's magnifying glass is taller
  /// than CupertinoIcons.search and sits further above the title (fitted:
  /// the title and description land where SwiftUI's do).
  static const double searchIconGap = 19;

  /// The gap between stacked actions (estimated).
  static const double actionSpacing = 12;

  /// The actions' default button size (measured: 15 pt labels).
  static const GlassControlSize actionsControlSize = GlassControlSize.small;
}
