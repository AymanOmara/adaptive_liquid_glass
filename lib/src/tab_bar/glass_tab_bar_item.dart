import 'package:flutter/cupertino.dart';

import 'glass_tab_bar.dart';

/// One tab of a [GlassTabBar]: an icon over a short label.
@immutable
class GlassTabBarItem {
  /// Creates a tab.
  const GlassTabBarItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.badge,
  });

  /// The tab's icon.
  final IconData icon;

  /// The tab's label, also its accessibility label.
  final String label;

  /// The icon while this tab is selected; defaults to [icon].
  final IconData? activeIcon;

  /// A badge on the icon: a count or short text, or a dot when empty.
  /// Null shows none.
  final String? badge;
}
