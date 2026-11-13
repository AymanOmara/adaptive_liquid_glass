import '../search/search_metrics.dart';

/// `GlassTextField`'s metrics. The single-line height, text size, the
/// prefix and trailing insets and the icon and clear-button sizes are
/// reused from SwiftUI's measured search field ([SearchMetrics]); the
/// rest is estimated, not measured.
abstract final class TextFieldMetrics {
  /// The single-line field's height; also a multi-line field's minimum.
  static const double height = SearchMetrics.height;

  /// The text's start inset when there is no prefix (estimated: slightly
  /// less than the search field's icon inset).
  static const double startInset = 16;

  /// The inset before a prefix widget.
  static const double prefixInset = SearchMetrics.startInset;

  /// The end inset when there is no trailing widget (estimated).
  static const double endInset = 16;

  /// The end inset when a clear button, eye or suffix is shown.
  static const double trailingInset = SearchMetrics.endInset;

  /// The gap between the prefix and the text.
  static const double iconGap = SearchMetrics.iconGap;

  /// The size given to a prefix or suffix through an [IconTheme].
  static const double iconSize = SearchMetrics.iconSize;

  /// The text size.
  static const double fontSize = SearchMetrics.fontSize;

  /// The clear button's glyph size.
  static const double clearSize = SearchMetrics.clearSize;

  /// The clear button's padding, widening its touch target.
  static const double clearPadding = SearchMetrics.clearPadding;

  /// A multi-line field's corner radius (estimated: half the single-line
  /// height, so one line matches the capsule).
  static const double multiLineRadius = 24;

  /// A multi-line field's vertical padding (estimated).
  static const double multiLineVerticalPadding = 13;

  /// The gap between the field and the error text (estimated).
  static const double errorGap = 6;

  /// The error text's size (iOS's footnote size).
  static const double errorFontSize = 13;

  /// The content's opacity when disabled (estimated).
  static const double disabledOpacity = 0.5;

  /// `GlassTextEditor`'s height when its parent leaves it unbounded.
  static const double editorHeight = 200;

  /// `GlassTextEditor`'s text inset from its sides: UITextView's 5-pt
  /// line-fragment padding plus the 11 pt SwiftUI places around a glass
  /// `TextEditor`.
  static const double editorHorizontalInset = 16;

  /// `GlassTextEditor`'s text inset from its top and bottom: UITextView's
  /// 8-pt text-container inset plus 5 pt of padding.
  static const double editorVerticalInset = 13;
}
