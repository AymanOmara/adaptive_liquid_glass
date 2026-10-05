import 'package:flutter/widgets.dart';

/// Scroll positions of the scrollables enclosing [context], innermost first.
///
/// Stops before [stopAt] when given (that scrollable and those outside it
/// are left out). Glass samples screen-space pixels, so whatever moves it
/// without repainting it, such as a viewport scrolling, must be listened to.
List<ScrollPosition> enclosingScrollPositions(
  BuildContext context, {
  ScrollableState? stopAt,
}) {
  final out = <ScrollPosition>[];
  var scrollable = Scrollable.maybeOf(context);
  while (scrollable != null && !identical(scrollable, stopAt)) {
    out.add(scrollable.position);
    scrollable = Scrollable.maybeOf(scrollable.context);
  }
  return out;
}
