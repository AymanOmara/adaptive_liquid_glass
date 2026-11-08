import 'package:flutter/cupertino.dart';

/// iOS 26's TipKit tips, measured from `TipView` and `.popoverTip` (iOS
/// 26.4, iPhone 17 Pro at 3x; `-controls tips` and `tippopover`) unless a
/// value says estimated. The popover's body uses the inline insets
/// (measured: the same offsets inside its bubble).
abstract final class TipMetrics {
  /// The platter's corner radius (fitted to the continuous corner).
  static const double cornerRadius = 26;

  /// The platter's hairline border width (measured: one device pixel).
  static const double borderWidth = 1 / 3;

  /// The content's top inset to the title's line box.
  static const double topInset = 16;

  /// The content's bottom inset under the text when there are no actions,
  /// and the text's gap to the actions when there are.
  static const double textBottomInset = 22;

  /// The content's leading inset to the image (or the text without one).
  static const double startInset = 22;

  /// The text's trailing inset, keeping it clear of the close button.
  static const double textEndInset = 40.33;

  /// The image's slot width.
  static const double imageSlotWidth = 38;

  /// The image's gap to the text.
  static const double imageGap = 13;

  /// The image's glyph size.
  static const double imageSize = 36;

  /// The title's size and weight (`.headline`) and line height.
  static const double titleSize = 17;

  /// The title's weight.
  static const FontWeight titleWeight = FontWeight.w600;

  /// The title's and message's line height.
  static const double lineHeight = 22;

  /// The message's size (`.subheadline`).
  static const double messageSize = 15;

  /// The title's gap to the message.
  static const double messageGap = 4;

  /// The close button's diameter.
  static const double closeSize = 26;

  /// The close button's inset from the top and trailing edges.
  static const double closeInset = 14;

  /// The close glyph's size (fitted to the xmark).
  static const double closeGlyphSize = 13;

  /// The actions' height.
  static const double actionHeight = 52;

  /// The gap between actions.
  static const double actionGap = 8;

  /// The actions' inset from the platter's sides and bottom.
  static const double actionInset = 16;

  /// The action label's size and weight.
  static const double actionLabelSize = 17;

  /// The popover bubble's width when the screen allows (measured: 319 pt
  /// on a 402 pt screen).
  static const double popoverMaxWidth = 319;

  /// The popover bubble's least gap to the screen's sides (estimated).
  static const double popoverScreenMargin = 16;

  /// The arrow's base width.
  static const double arrowWidth = 27;

  /// The arrow's height.
  static const double arrowHeight = 13;

  /// The arrow tip's gap to the anchor.
  static const double arrowGap = 1;

  /// The room above the anchor that puts the bubble above it, as TipKit
  /// prefers (estimated: a two-line tip).
  static const double popoverAboveRoom = 140;

  /// The inline platter (measured: systemGray6 light and dark).
  static const CupertinoDynamicColor background =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFF2F2F7),
        darkColor: Color(0xFF1C1C1E),
      );

  /// The inline platter's hairline (measured).
  static const CupertinoDynamicColor border =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFE6E6E7),
        darkColor: Color(0xFF262627),
      );

  /// The popover bubble (measured light; dark estimated, as the native
  /// popover kept the light appearance in the dark reference scene).
  static const CupertinoDynamicColor popoverBackground =
      CupertinoDynamicColor.withBrightness(
        color: Color(0xFFF5F5F4),
        darkColor: Color(0xFF2C2C2E),
      );

  /// The popover's soft shadow (estimated).
  static const Color popoverShadow = Color(0x24000000);

  /// The close button's and secondary actions' fill (measured:
  /// systemFill over the platter).
  static const CupertinoDynamicColor fill = CupertinoColors.systemFill;
}
