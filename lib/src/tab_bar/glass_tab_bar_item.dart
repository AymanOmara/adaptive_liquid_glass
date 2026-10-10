import 'package:flutter/cupertino.dart';

import 'glass_tab_bar.dart';

/// One tab of a [GlassTabBar]: an icon over a short label.
@immutable
class GlassTabBarItem {
  /// Creates a tab.
  const GlassTabBarItem({
    required IconData this.icon,
    required this.label,
    this.activeIcon,
    this.badge,
  }) : iconWidget = null,
       activeIconWidget = null;

  /// Creates a tab with widget icons, e.g. an SVG or an image.
  ///
  /// The tab bar draws them inside an [IconTheme] with its icon size and
  /// colour, so [Icon]s and widgets that read the theme (such as SVGs
  /// tinted from `IconTheme.of(context).color`) take the bar's colour;
  /// images keep their own colours. Size them to the theme's size.
  const GlassTabBarItem.custom({
    required Widget this.iconWidget,
    required this.label,
    this.activeIconWidget,
    this.badge,
  }) : icon = null,
       activeIcon = null;

  /// The tab's icon; null for [GlassTabBarItem.custom].
  final IconData? icon;

  /// The tab's label, also its accessibility label.
  final String label;

  /// The icon while this tab is selected; defaults to [icon].
  final IconData? activeIcon;

  /// The tab's icon widget, for [GlassTabBarItem.custom].
  final Widget? iconWidget;

  /// The icon widget while this tab is selected; defaults to [iconWidget].
  final Widget? activeIconWidget;

  /// The icon to draw, selected or not, with its colour and size from the
  /// enclosing [IconTheme].
  Widget iconFor({required bool selected}) {
    final glyph = selected ? activeIcon ?? icon : icon;
    if (glyph != null) return Icon(glyph);
    return selected ? activeIconWidget ?? iconWidget! : iconWidget!;
  }

  /// A badge on the icon: a count or short text, or a dot when empty.
  /// Null shows none.
  final String? badge;
}
