import 'package:flutter/widgets.dart';

/// A navigation bar action that stands apart from the bar's glass, like a
/// SwiftUI `ToolbarItem` with `sharedBackgroundVisibility(.hidden)`.
///
/// In `GlassNavigationBar.actions` (or `SliverGlassNavigationBar.actions`)
/// it is its own group, laid out in a 44-pt cell with no capsule behind
/// it. The bar does not strip glass from [child]: give it content that
/// draws none, such as an avatar or a
/// `GlassButton.icon(style: GlassButtonStyle.plain)`. Elsewhere (and on
/// the Material path) it is just [child].
///
/// ```dart
/// actions: [
///   GlassButton.icon(onPressed: share, icon: CupertinoIcons.share),
///   GlassBarItem(
///     sharedBackground: false,
///     child: GlassButton.icon(
///       onPressed: openProfile,
///       icon: CupertinoIcons.person_crop_circle_fill,
///       style: GlassButtonStyle.plain,
///     ),
///   ),
/// ]
/// ```
class GlassBarItem extends StatelessWidget {
  /// Creates a bar item.
  const GlassBarItem({
    super.key,
    this.sharedBackground = true,
    required this.child,
  });

  /// Whether the item shares the bar's glass with its neighbours. False
  /// sets it apart with no capsule behind it.
  final bool sharedBackground;

  /// The item.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
