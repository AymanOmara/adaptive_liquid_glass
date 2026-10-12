import 'package:flutter/cupertino.dart';

import '../core/glass_colors.dart';
import 'control_metrics.dart';

/// The "I" and "O" marks iOS draws on a switch's track when On/Off Labels
/// is on (`MediaQuery.onOffSwitchLabelsOf`), so its state does not rest on
/// colour alone. "I" sits at the start, uncovered while on; "O" at the
/// end, uncovered while off. Both fade while the thumb is held, as UIKit's.
class GlassToggleLabels extends StatelessWidget {
  /// Creates the marks for a thumb at [position] (0 off, 1 on).
  const GlassToggleLabels({
    super.key,
    required this.position,
    required this.pressed,
  });

  /// 0 off, 1 on.
  final double position;

  /// 0 at rest, 1 held.
  final double pressed;

  @override
  Widget build(BuildContext context) {
    final rest = (1 - pressed).clamp(0.0, 1.0);
    const on = ControlMetrics.toggleOnLabel;
    const r = ControlMetrics.toggleOffLabelRadius;
    return Stack(
      children: [
        PositionedDirectional(
          start: ControlMetrics.toggleOnLabelInset - on.width / 2,
          top: 0,
          bottom: 0,
          width: on.width,
          child: Center(
            child: Opacity(
              opacity: position * rest,
              child: SizedBox.fromSize(
                size: on,
                child: const ColoredBox(color: GlassColors.toggleOnLabel),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: ControlMetrics.toggleOffLabelInset - r,
          top: 0,
          bottom: 0,
          width: r * 2,
          child: Center(
            child: Opacity(
              opacity: (1 - position) * rest,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoDynamicColor.resolve(
                      GlassColors.toggleOffLabel,
                      context,
                    ),
                  ),
                ),
                child: const SizedBox.square(dimension: r * 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
