import 'package:flutter/cupertino.dart';

import '../core/glass_colors.dart';
import '../core/glass_system_colors.dart';
import 'glass_swipe_action.dart';
import 'swipe_metrics.dart';

/// A revealed swipe action, as SwiftUI draws it: a compact capsule with
/// its icon and label inside, or (in a tall row) an icon-only capsule or
/// circle with the label under it. [width] past [naturalWidth] stretches
/// the capsule with its content centred; once it has [taken] the whole
/// swipe its content stays at the side by the row.
class SwipeActionButton extends StatelessWidget {
  /// Creates the button for [action].
  const SwipeActionButton({
    super.key,
    required this.action,
    required this.onPressed,
    required this.stacked,
    required this.width,
    required this.naturalWidth,
    required this.height,
    required this.rowOnLeft,
    this.labelGap = SwipeMetrics.stackedLabelGap,
    this.taken = false,
  });

  /// The action shown.
  final GlassSwipeAction action;

  /// Runs the action.
  final VoidCallback onPressed;

  /// Whether the label goes under the capsule (a tall row).
  final bool stacked;

  /// The capsule's width now.
  final double width;

  /// The capsule's width at rest.
  final double naturalWidth;

  /// The capsule's height.
  final double height;

  /// Whether the row is to the button's left: a stretched capsule keeps
  /// its content on that side.
  final bool rowOnLeft;

  /// The gap between a stacked capsule and its label's ink.
  final double labelGap;

  /// Whether the action has taken the whole swipe (past the full-swipe
  /// point): its content keeps to the row's side.
  final bool taken;

  @override
  Widget build(BuildContext context) {
    // SwiftUI draws the capsules in their tint, opaque.
    final tint = CupertinoDynamicColor.resolve(
      action.color ??
          (action.destructive
              ? GlassSystemColors.red
              : GlassColors.swipeActionDefault),
      context,
    );
    final side = !taken
        ? Alignment.center
        : rowOnLeft
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final Widget content = stacked
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
                SizedBox(
                  width: SwipeMetrics.compactIconWidth,
                  height: SwipeMetrics.compactIconSize,
                  child: OverflowBox(
                    maxWidth: SwipeMetrics.compactIconSize,
                    child: Icon(
                      action.icon,
                      size: SwipeMetrics.compactIconSize,
                      color: GlassColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: SwipeMetrics.compactIconGap),
                Text(
                  action.label,
                  maxLines: 1,
                  style: SwipeMetrics.label.copyWith(color: GlassColors.white),
                ),
              ],
            ),
          );
    final capsule = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: const StadiumBorder(), color: tint),
        child: Align(
          alignment: side,
          child: SizedBox(
            width: naturalWidth,
            child: Center(child: content),
          ),
        ),
      ),
    );
    // The row exposes its actions as custom semantics actions.
    return ExcludeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: !stacked
            ? capsule
            : Column(
                children: [
                  capsule,
                  // The gap is to the label's ink; its line box starts
                  // above that.
                  SizedBox(height: labelGap - SwipeMetrics.labelInkTop),
                  // Under the icon, however wide the label.
                  Align(
                    alignment: side,
                    child: SizedBox(
                      width: naturalWidth,
                      height: SwipeMetrics.stackedLabelHeight,
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minWidth: 0,
                        minHeight: 0,
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: Text(
                          action.label,
                          maxLines: 1,
                          softWrap: false,
                          style: SwipeMetrics.label.copyWith(
                            color: CupertinoDynamicColor.resolve(
                              GlassColors.secondaryLabel,
                              context,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
