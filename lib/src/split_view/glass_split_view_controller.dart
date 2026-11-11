import 'package:flutter/widgets.dart';

import 'glass_split_view_column.dart';

/// The state of a [GlassSplitView]: which columns a wide layout shows and
/// which column a compact one is on (SwiftUI's `columnVisibility` and
/// `preferredCompactColumn` bindings).
///
/// Pass one to `GlassSplitView.controller` to drive it; without one the
/// view makes its own, reachable from its columns through
/// `GlassSplitView.of(context)`.
class GlassSplitViewController extends ChangeNotifier {
  /// Creates a controller.
  GlassSplitViewController({
    GlassSplitViewVisibility visibility = GlassSplitViewVisibility.automatic,
    GlassSplitViewColumn compactColumn = GlassSplitViewColumn.sidebar,
  }) : _visibility = visibility,
       _compactColumn = compactColumn;

  GlassSplitViewVisibility _visibility;
  GlassSplitViewColumn _compactColumn;

  /// The columns shown at regular width.
  GlassSplitViewVisibility get visibility => _visibility;
  set visibility(GlassSplitViewVisibility value) {
    if (value == _visibility) return;
    _visibility = value;
    notifyListeners();
  }

  /// The column shown at compact width.
  GlassSplitViewColumn get compactColumn => _compactColumn;
  set compactColumn(GlassSplitViewColumn value) {
    if (value == _compactColumn) return;
    _compactColumn = value;
    notifyListeners();
  }

  /// Shows [column]: at compact width it pushes (or pops to) it; at regular
  /// width it makes sure the column is visible.
  void showColumn(GlassSplitViewColumn column) {
    compactColumn = column;
    switch (column) {
      case GlassSplitViewColumn.sidebar:
        visibility = GlassSplitViewVisibility.all;
      case GlassSplitViewColumn.content:
        if (visibility == GlassSplitViewVisibility.detailOnly) {
          visibility = GlassSplitViewVisibility.doubleColumn;
        }
      case GlassSplitViewColumn.detail:
        break;
    }
  }

  /// The sidebar button's action: hides the sidebar, or shows it again.
  void toggleSidebar() {
    visibility = switch (visibility) {
      GlassSplitViewVisibility.automatic ||
      GlassSplitViewVisibility.all => GlassSplitViewVisibility.detailOnly,
      _ => GlassSplitViewVisibility.all,
    };
  }
}
