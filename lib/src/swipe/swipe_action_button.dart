import 'package:flutter/cupertino.dart';

import '../core/glass_colors.dart';
import 'glass_swipe_action.dart';
import 'swipe_metrics.dart';

/// A revealed swipe action, as SwiftUI lays it out: a compact capsule
/// with its icon and label inside, or (in a tall row) an icon-only capsule
/// with the label under it. It fills the width it is given.
class SwipeActionButton extends StatelessWidget {
  /// Creates the button for [action].
  const SwipeActionButton({
    super.key,
    required this.action,
    required this.onPressed,
    required this.stacked,
    required this.rowHeight,
  });

  /// The action shown.
  final GlassSwipeAction action;

  /// Runs the action.
  final VoidCallback onPressed;

  /// Whether the label goes under the capsule (a tall row).
  final bool stacked;

  /// The row's height, which a compact capsule follows.
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    // SwiftUI draws the capsules in their tint, opaque.
    final tint = CupertinoDynamicColor.resolve(
      action.color ?? CupertinoColors.systemGrey,
      context,
    );
    final capsule = DecoratedBox(
      decoration: ShapeDecoration(shape: const StadiumBorder(), color: tint),
      child: Center(
        child: stacked
            ? Icon(
                action.icon,
                size: SwipeMetrics.stackedIconSize,
                color: GlassColors.white,
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      action.icon,
                      size: SwipeMetrics.compactIconSize,
                      color: GlassColors.white,
                    ),
                    const SizedBox(width: SwipeMetrics.compactIconGap),
                    Text(
                      action.label,
                      maxLines: 1,
                      style: SwipeMetrics.label.copyWith(
                        color: GlassColors.white,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
    // The row exposes its actions as custom semantics actions.
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: stacked
            ? Column(
                children: [
                  const SizedBox(height: SwipeMetrics.stackedInset),
                  SizedBox(height: SwipeMetrics.stackedHeight, child: capsule),
                  const SizedBox(height: SwipeMetrics.stackedLabelGap),
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: SwipeMetrics.label.copyWith(
                      color: CupertinoDynamicColor.resolve(
                        CupertinoColors.secondaryLabel,
                        context,
                      ),
                    ),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: SwipeMetrics.compactInset,
                ),
                child: SizedBox(
                  height: rowHeight - SwipeMetrics.compactInset * 2,
                  child: capsule,
                ),
              ),
      ),
    );
  }
}
