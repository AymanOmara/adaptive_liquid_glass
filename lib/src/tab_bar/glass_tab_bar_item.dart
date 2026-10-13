import 'package:flutter/cupertino.dart';

import '../symbol/glass_symbol.dart';
import 'glass_tab_bar.dart';
import 'tab_bar_metrics.dart';

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
       activeIconWidget = null,
       isSpacer = false;

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
       activeIcon = null,
       isSpacer = false;

  /// A tab whose icon is the SF Symbol [symbol] (e.g. `house.fill`), drawn
  /// by iOS at run time as `TabView` draws it; [fallback] is used elsewhere.
  /// [activeSymbol] replaces it while selected.
  GlassTabBarItem.symbol(
    String symbol, {
    required IconData fallback,
    required this.label,
    String? activeSymbol,
    IconData? activeFallback,
    this.badge,
  }) : iconWidget = _symbol(symbol, fallback),
       activeIconWidget = activeSymbol == null
           ? null
           : _symbol(activeSymbol, activeFallback ?? fallback),
       icon = null,
       activeIcon = null,
       isSpacer = false;

  /// An empty slot, e.g. under a floating action centred over the bar.
  ///
  /// It draws nothing, takes no taps and has no accessibility node: a
  /// press released over it leaves the lens on the selected tab. It must
  /// not be the selected tab.
  const GlassTabBarItem.spacer()
    : icon = null,
      label = '',
      activeIcon = null,
      iconWidget = null,
      activeIconWidget = null,
      badge = null,
      isSpacer = true;

  /// Whether this is a [GlassTabBarItem.spacer].
  final bool isSpacer;

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

  /// A tab symbol: SwiftUI's `TabView` (iOS 26.4) sets its symbols'
  /// centres TabBarMetrics.symbolRise above the icon box's.
  static Widget _symbol(String name, IconData fallback) => Transform.translate(
    offset: const Offset(0, -TabBarMetrics.symbolRise),
    child: GlassSymbol(
      name,
      fallback: fallback,
      pointSize: TabBarMetrics.symbolPointSize,
      weight: TabBarMetrics.symbolWeight,
      scale: TabBarMetrics.symbolScale,
    ),
  );
}
