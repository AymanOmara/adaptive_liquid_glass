import 'package:flutter/widgets.dart';

/// A button under a tip's message, like TipKit's `Tip.Action`.
@immutable
class GlassTipAction {
  /// Creates an action; [label] is your own (localised) text.
  const GlassTipAction({required this.label, required this.onPressed});

  /// The button's text, e.g. "Learn More".
  final String label;

  /// Called on tap. The tip stays up: call
  /// `GlassTipController.dismiss(GlassTipDismissReason.actionPerformed)`
  /// to put it away, as TipKit's `invalidate(reason:)` does.
  final VoidCallback onPressed;
}

/// What a tip says, like a TipKit `Tip`: a title, an optional message and
/// image, and actions. One value feeds both [GlassTipView] (inline) and
/// `GlassPopoverTip` (`.popoverTip`).
///
/// ```dart
/// const favoriteTip = GlassTip(
///   image: Icon(CupertinoIcons.star),
///   title: Text('Save as a Favorite'),
///   message: Text('Your favorite places appear at the top of the list.'),
/// );
/// ```
@immutable
class GlassTip {
  /// Creates a tip's content.
  const GlassTip({
    required this.title,
    this.message,
    this.image,
    this.actions = const [],
  });

  /// The bold first line, e.g. `Text('Save as a Favorite')`.
  final Widget title;

  /// The explanation under the title.
  final Widget? message;

  /// The leading glyph, e.g. `Icon(CupertinoIcons.star)`; tinted and sized
  /// by the tip.
  final Widget? image;

  /// Capsule buttons under the text, side by side like TipKit's: the
  /// first is the prominent one, on the trailing side.
  final List<GlassTipAction> actions;
}
