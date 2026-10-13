/// When a [GlassTabBar] in a [GlassScaffold] shrinks to its selected tab,
/// as SwiftUI's `tabBarMinimizeBehavior`.
library;

import '../scaffold/glass_scaffold.dart';
import 'glass_tab_bar.dart';

/// When a [GlassTabBar] in a [GlassScaffold] shrinks to its selected tab.
enum GlassTabBarMinimizeBehavior {
  /// The system's choice: never on iPhone, as SwiftUI's `.automatic`.
  automatic,

  /// The bar keeps its full size.
  never,

  /// Scrolling the page down shrinks the bar to a circle holding the
  /// selected tab; scrolling back to the top, or tapping the circle,
  /// brings it back (SwiftUI `.onScrollDown`, measured on iOS 26.4).
  onScrollDown,
}
