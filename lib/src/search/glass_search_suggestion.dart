import 'package:flutter/widgets.dart';

/// One row of a [GlassSearchable]'s suggestions.
///
/// ```dart
/// GlassSearchSuggestion(
///   title: const Text('Copied Image'),
///   leading: const Icon(CupertinoIcons.doc),
///   onSelected: open,
/// )
/// ```
///
/// Tapping the row copies the title into the field when it is a [Text],
/// then calls [onSelected].
@immutable
class GlassSearchSuggestion {
  /// Creates a suggestion.
  const GlassSearchSuggestion({
    required this.title,
    this.subtitle,
    this.leading,
    this.onSelected,
    this.semanticLabel,
  });

  /// The row's main text, usually a plain [Text] so it can be copied
  /// into the field.
  final Widget title;

  /// A second line under the title.
  final Widget? subtitle;

  /// The row's start slot, usually an icon.
  final Widget? leading;

  /// Called when the row is tapped, after the searchable has put [title]'s
  /// text (when it is a [Text]) into the field. Null draws a plain row.
  final VoidCallback? onSelected;

  /// What assistive tech reads for the row, instead of the title.
  final String? semanticLabel;
}
