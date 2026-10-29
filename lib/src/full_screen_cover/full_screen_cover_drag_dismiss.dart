import 'package:flutter/gestures.dart' show VerticalDragGestureRecognizer;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/widgets.dart';

import 'full_screen_cover_metrics.dart';
import 'glass_full_screen_cover_drag_configuration.dart';

/// Optional cover drag with an explicit app-defined release policy.
/// Respects PopScope, child scrollables and Reduce Motion. With [enabled]
/// false it is [child] alone; SwiftUI's full-screen cover does not drag.
class FullScreenCoverDragDismiss extends StatefulWidget {
  /// Creates the drag wrapper.
  const FullScreenCoverDragDismiss({
    super.key,
    required this.enabled,
    required this.child,
    this.configuration = const GlassFullScreenCoverDragConfiguration(),
  });

  /// Whether a drag dismisses the cover.
  final bool enabled;

  /// Release thresholds, resistance and return spring.
  final GlassFullScreenCoverDragConfiguration configuration;

  /// The cover's page.
  final Widget child;

  @override
  State<FullScreenCoverDragDismiss> createState() =>
      _FullScreenCoverDragDismissState();
}

class _FullScreenCoverDragDismissState extends State<FullScreenCoverDragDismiss>
    with SingleTickerProviderStateMixin {
  /// The cover's offset below its resting place.
  late final AnimationController _offset;

  /// Set once the cover is popping, so a late drag cannot pull it back.
  bool _dismissing = false;
  double _dragOffset = 0;
  int _settleRevision = 0;

  // Created here, not lazily: one first read in dispose would create
  // its ticker on a deactivated element.
  @override
  void initState() {
    super.initState();
    _offset = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(FullScreenCoverDragDismiss oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) {
      _settleRevision++;
      _offset.stop();
      _offset.value = 0;
      _dragOffset = 0;
    }
  }

  void _start(DragStartDetails details) {
    if (_dismissing) return;
    _settleRevision++;
    _offset.stop();
    final resistance = widget.configuration.upwardResistance;
    _dragOffset = _offset.value < 0
        ? (resistance > 0 ? _offset.value / resistance : 0)
        : _offset.value;
  }

  void _update(DragUpdateDetails d) {
    if (_dismissing) return;
    _dragOffset += d.delta.dy;
    // Apply resistance to total travel, not repeatedly to each displayed
    // offset: the result must not depend on pointer-event frequency.
    _offset.value = _dragOffset < 0
        ? _dragOffset * widget.configuration.upwardResistance
        : _dragOffset;
  }

  void _cancel() {
    if (!_dismissing) _settle(0);
  }

  void _end(DragEndDetails d) {
    if (_dismissing) return;
    final v = d.velocity.pixelsPerSecond.dy;
    final height = context.size?.height ?? 0;
    final policy = widget.configuration;
    final dismiss =
        _offset.value > 0 &&
        (v > policy.flingVelocity ||
            (_offset.value > height * policy.dismissFraction &&
                v > -policy.flingVelocity));
    if (dismiss) {
      _dismiss();
    } else {
      _settle(v);
    }
  }

  /// Springs the cover back into place at [velocity].
  void _settle(double velocity) {
    final revision = ++_settleRevision;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _offset.value = 0;
      return;
    }
    _offset
        .animateWith(
          SpringSimulation(
            widget.configuration.settleSpring ?? FullScreenCoverMetrics.spring,
            _offset.value,
            0,
            velocity,
          ),
        )
        .whenComplete(() {
          if (mounted && !_dismissing && revision == _settleRevision) {
            _offset.value = 0;
          }
        });
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _dismissing = false;
      _settle(0);
      return;
    }
    await Navigator.maybePop(context);
    // A PopScope that refused: spring back as after a short drag.
    if (mounted &&
        route != null &&
        route.isActive &&
        route.animation?.status != AnimationStatus.reverse) {
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
                  ..onStart = _start
                  ..onUpdate = _update
                  ..onEnd = _end
                  ..onCancel = _cancel,
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
