import 'package:flutter/gestures.dart' show VerticalDragGestureRecognizer;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/widgets.dart';

import 'full_screen_cover_metrics.dart';

/// Lets a full-screen cover be dragged down and released to dismiss, like
/// iOS 26's sheet: past [FullScreenCoverMetrics.dismissFraction] of its
/// height, or flung down faster than
/// [FullScreenCoverMetrics.flingVelocity], it pops its route (respecting
/// `PopScope`); otherwise it springs back. Assistive tech gets a dismiss
/// action instead. With [enabled] false it is [child] alone.
class FullScreenCoverDragDismiss extends StatefulWidget {
  /// Creates the drag wrapper.
  const FullScreenCoverDragDismiss({
    super.key,
    required this.enabled,
    required this.child,
  });

  /// Whether a drag dismisses the cover.
  final bool enabled;

  /// The cover's page.
  final Widget child;

  @override
  State<FullScreenCoverDragDismiss> createState() =>
      _FullScreenCoverDragDismissState();
}

class _FullScreenCoverDragDismissState extends State<FullScreenCoverDragDismiss>
    with SingleTickerProviderStateMixin {
  /// The cover's offset below its resting place.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );

  /// Set once the cover is popping, so a late drag cannot pull it back.
  bool _dismissing = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails d) {
    if (_dismissing) return;
    _offset.stop();
    final next = _offset.value + d.delta.dy;
    // Down freely; up only a little, with resistance.
    _offset.value = next < 0
        ? next * FullScreenCoverMetrics.upwardResistance
        : next;
  }

  void _end(DragEndDetails d) {
    if (_dismissing) return;
    final v = d.velocity.pixelsPerSecond.dy;
    final height = context.size?.height ?? 0;
    final dismiss =
        v > FullScreenCoverMetrics.flingVelocity ||
        (_offset.value > height * FullScreenCoverMetrics.dismissFraction &&
            v > -FullScreenCoverMetrics.flingVelocity);
    if (dismiss) {
      _dismiss();
    } else {
      _settle(v);
    }
  }

  /// Springs the cover back into place at [velocity].
  void _settle(double velocity) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _offset.value = 0;
      return;
    }
    _offset
        .animateWith(
          SpringSimulation(
            FullScreenCoverMetrics.spring,
            _offset.value,
            0,
            velocity,
          ),
        )
        .whenComplete(() {
          if (mounted && !_dismissing) _offset.value = 0;
        });
  }

  Future<void> _dismiss() async {
    _dismissing = true;
    final route = ModalRoute.of(context);
    await Navigator.maybePop(context);
    // A PopScope that refused: spring back as after a short drag.
    if (mounted && route != null && route.isCurrent) {
      _dismissing = false;
      _settle(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Semantics(
      onDismiss: _dismissing ? null : _dismiss,
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: <Type, GestureRecognizerFactory>{
          VerticalDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                VerticalDragGestureRecognizer
              >(
                VerticalDragGestureRecognizer.new,
                (r) => r
                  ..onUpdate = _update
                  ..onEnd = _end,
              ),
        },
        child: AnimatedBuilder(
          animation: _offset,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _offset.value),
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
