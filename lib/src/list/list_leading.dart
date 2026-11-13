import 'package:flutter/widgets.dart';

import '../swipe/glass_swipe_actions.dart';
import 'glass_list_tile.dart';

/// Internal. Whether [row] is a [GlassListTile] with a leading, looking
/// through a [GlassSwipeActions] around it, so a swipeable row's hairline
/// starts under its title as a plain row's does.
bool hasLeading(Widget row) {
  final tile = row is GlassSwipeActions ? row.child : row;
  return tile is GlassListTile && tile.leading != null;
}
