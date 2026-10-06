import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_colors.dart';
import '../core/glass_render_mode.dart';
import '../liquid_glass.dart';
import 'glass_swipe_action.dart';
import 'swipe_metrics.dart';

/// A revealed swipe action: its tinted capsule, filling the width it is
/// given, with the label under it.
class SwipeActionButton extends StatelessWidget {
  /// Creates the button for [action].
  const SwipeActionButton({
    super.key,
    required this.action,
    required this.onPressed,
    this.mode,
  });

  /// The action shown.
  final GlassSwipeAction action;

  /// Runs the action.
  final VoidCallback onPressed;

  /// The capsule's rendering path.
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    final tint = CupertinoDynamicColor.resolve(
      action.color ?? CupertinoColors.systemGrey,
      context,
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: SwipeMetrics.capsuleHeight,
          width: double.infinity,
          child: LiquidGlass(
            glass: Glass.regular.tint(tint),
            mode: mode,
            onPressed: onPressed,
            child: Center(
              child: Icon(
                action.icon,
                size: SwipeMetrics.iconSize,
                color: GlassColors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: SwipeMetrics.labelGap),
        Text(
          action.label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          softWrap: false,
          style: TextStyle(
            fontSize: SwipeMetrics.labelSize,
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.secondaryLabel,
              context,
            ),
          ),
        ),
      ],
    );
    // The row exposes its actions as custom semantics actions.
    return ExcludeSemantics(
      // The label is part of the target too; the capsule's own press wins
      // over it, so a tap runs the action once.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: LayoutBuilder(
          builder: (context, box) {
            // A row shorter than capsule and label scales the action down,
            // keeping it as wide as its slot.
            final scale = box.maxHeight < SwipeMetrics.actionHeight
                ? box.maxHeight / SwipeMetrics.actionHeight
                : 1.0;
            return Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(width: box.maxWidth / scale, child: column),
              ),
            );
          },
        ),
      ),
    );
  }
}
