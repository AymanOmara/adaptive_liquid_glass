import 'package:flutter/widgets.dart';

/// One segment of a [GlassSegmentedControl]: a [value] and its label.
@immutable
class GlassSegment<T> {
  /// Creates a segment.
  const GlassSegment({
    required this.value,
    required this.label,
    this.semanticLabel,
  });

  /// The value the segment selects.
  final T value;

  /// The segment's label, usually a short [Text] or an [Icon].
  final Widget label;

  /// What assistive tech reads; needed when [label] is an icon.
  final String? semanticLabel;
}
