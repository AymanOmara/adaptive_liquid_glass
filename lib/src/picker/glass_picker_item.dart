import 'package:flutter/widgets.dart';

/// One choice of a [GlassPicker]: a [value] and its label.
@immutable
class GlassPickerItem<T> {
  /// Creates a choice.
  const GlassPickerItem({required this.value, required this.label});

  /// The value the choice selects.
  final T value;

  /// The choice's label, in the picker and its menu.
  final String label;
}
