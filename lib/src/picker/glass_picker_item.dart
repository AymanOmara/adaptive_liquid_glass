import 'package:flutter/widgets.dart';

/// One choice of a [GlassPicker]: a [value], its label and, for the
/// palette style, an optional [icon].
@immutable
class GlassPickerItem<T> {
  /// Creates a choice.
  const GlassPickerItem({required this.value, required this.label, this.icon});

  /// The value the choice selects.
  final T value;

  /// The choice's label, in the picker and its menu. When [icon] shows,
  /// it is what assistive tech reads.
  final String label;

  /// The palette style's glyph in place of the label (say,
  /// `CupertinoIcons.star`); the other styles show the label.
  final IconData? icon;
}
