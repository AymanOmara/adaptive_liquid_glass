import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, TextButton, Theme;
import 'package:flutter/physics.dart';

import '../core/glass_colors.dart';
import '../core/ios_text.dart';
import '../liquid_glass.dart';
import 'toast_metrics.dart';
import 'toast_request.dart';

/// One toast on screen: springs in from its edge, answers a swipe and
/// the auto-dismiss timer, then reports itself closed. Internal.
class GlassToastView extends StatefulWidget {
  /// Creates the view the queue inserts into the overlay.
  const GlassToastView({
    super.key,
    required this.request,
    required this.material,
    required this.onClosed,
  });

  /// What the toast shows.
  final ToastRequest request;

  /// Whether the Material path is used (no `ScaffoldMessenger` above).
  final bool material;

  /// Called once the toast has finished leaving the screen.
  final VoidCallback onClosed;

  @override
  State<GlassToastView> createState() => _GlassToastViewState();
}

class _GlassToastViewState extends State<GlassToastView>
    with SingleTickerProviderStateMixin {
  /// 0 hidden, 1 shown; springs past both.
  late final AnimationController _show = AnimationController.unbounded(
    vsync: this,
  );

  /// The vertical drag, positive towards the screen's edge.
  double _drag = 0;
  Timer? _timer;
  bool _entered = false;
  bool _closing = false;
  bool _closed = false;

  bool get _reduceMotion => MediaQuery.disableAnimationsOf(context);

  /// How far the capsule travels to be fully off screen.
  double get _travel =>
      MediaQuery.paddingOf(context).top +
      ToastMetrics.topGap +
      2 * ToastMetrics.minHeight;

  @override
  void initState() {
    super.initState();
    widget.request.animateOut = _close;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_entered) {
      _entered = true;
      _enter();
    }
    if (widget.request.dismissRequested) _close();
  }

  void _enter() {
    if (_reduceMotion) {
      _show.animateTo(
        1,
        duration: ToastMetrics.fadeDuration,
        curve: Curves.linear,
      );
    } else {
      _show.animateWith(SpringSimulation(ToastMetrics.enter, 0, 1, 0));
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    final duration = widget.request.duration;
    if (duration == null) return;
    _timer = Timer(duration, () => _close());
  }

  void _close({double velocity = 0}) {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (_reduceMotion) {
      _show
          .animateTo(
            0,
            duration: ToastMetrics.fadeDuration,
            curve: Curves.linear,
          )
          .whenCompleteOrCancel(_finished);
    } else {
      _show
          .animateWith(
            SpringSimulation(ToastMetrics.exit, _show.value, 0, velocity),
          )
          .whenCompleteOrCancel(_finished);
    }
  }

  void _finished() {
    if (_closed) return;
    _closed = true;
    widget.onClosed();
  }

  void _dragStart(DragStartDetails details) {
    _timer?.cancel();
  }

  void _dragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    final d = details.delta.dy * (widget.material ? 1 : -1);
    setState(() {
      _drag += d > 0 ? d : d * ToastMetrics.dragResistance;
    });
  }

  void _dragEnd(DragEndDetails details) {
    final v = details.velocity.pixelsPerSecond.dy * (widget.material ? 1 : -1);
    if (_drag >= ToastMetrics.dismissDistance ||
        v > ToastMetrics.dismissVelocity) {
      // Carry the fling into the exit spring (in travels per second).
      _close(velocity: -v.clamp(0, double.infinity) / _travel);
    } else {
      setState(() => _drag = 0);
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.request.animateOut = null;
    _show.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.material ? _materialLayout(context) : _glassLayout(context);

  Widget _glassLayout(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + ToastMetrics.topGap,
      left: ToastMetrics.sideInset,
      right: ToastMetrics.sideInset,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: ToastMetrics.maxWidth),
          child: AnimatedBuilder(
            animation: _show,
            builder: (context, _) {
              final toast = GestureDetector(
                onVerticalDragStart: _dragStart,
                onVerticalDragUpdate: _dragUpdate,
                onVerticalDragEnd: _dragEnd,
                child: _glassToast(context),
              );
              if (_reduceMotion) {
                return Opacity(
                  opacity: _show.value.clamp(0.0, 1.0),
                  child: toast,
                );
              }
              return Transform.translate(
                offset: Offset(0, (_show.value - 1) * _travel - _drag),
                child: toast,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _glassToast(BuildContext context) {
    final request = widget.request;
    final action = request.action;
    return DefaultTextStyle(
      style: IOSText.style(ToastMetrics.fontSize),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: LiquidGlass(
          glass: request.glass,
          mode: request.mode,
          padding: EdgeInsetsDirectional.only(
            start: ToastMetrics.startPadding,
            end: action != null
                ? ToastMetrics.actionEndPadding
                : ToastMetrics.endPadding,
            top: ToastMetrics.verticalPadding,
            bottom: ToastMetrics.verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight:
                  ToastMetrics.minHeight - 2 * ToastMetrics.verticalPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (request.icon != null) ...[
                  Icon(request.icon, size: ToastMetrics.iconSize),
                  const SizedBox(width: ToastMetrics.iconGap),
                ],
                Flexible(
                  child: Text(
                    request.message,
                    maxLines: ToastMetrics.maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: IOSText.style(
                      ToastMetrics.fontSize,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: ToastMetrics.actionGap),
                  Semantics(
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        action.onPressed();
                        _close();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(
                          ToastMetrics.actionPadding,
                        ),
                        child: Text(
                          action.label,
                          style: IOSText.style(
                            ToastMetrics.fontSize,
                            weight: FontWeight.w600,
                            color: CupertinoDynamicColor.resolve(
                              GlassColors.toastAction,
                              context,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _materialLayout(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.paddingOf(context).bottom + ToastMetrics.materialInset,
      left: ToastMetrics.materialInset,
      right: ToastMetrics.materialInset,
      child: AnimatedBuilder(
        animation: _show,
        builder: (context, _) {
          final toast = GestureDetector(
            onVerticalDragStart: _dragStart,
            onVerticalDragUpdate: _dragUpdate,
            onVerticalDragEnd: _dragEnd,
            child: _materialToast(context),
          );
          final opacity = _show.value.clamp(0.0, 1.0);
          if (_reduceMotion) {
            return Opacity(opacity: opacity, child: toast);
          }
          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(
                0,
                (1 - _show.value) * 2 * ToastMetrics.minHeight + _drag,
              ),
              child: toast,
            ),
          );
        },
      ),
    );
  }

  Widget _materialToast(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final request = widget.request;
    final action = request.action;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: scheme.inverseSurface,
        elevation: ToastMetrics.materialElevation,
        borderRadius: BorderRadius.circular(ToastMetrics.materialRadius),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: ToastMetrics.materialStartPadding,
            end: action != null
                ? ToastMetrics.materialEndPadding
                : ToastMetrics.materialStartPadding,
            top: ToastMetrics.materialVerticalPadding,
            bottom: ToastMetrics.materialVerticalPadding,
          ),
          child: Row(
            children: [
              if (request.icon != null) ...[
                Icon(request.icon, color: scheme.onInverseSurface),
                const SizedBox(width: ToastMetrics.iconGap),
              ],
              Expanded(
                child: Text(
                  request.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onInverseSurface,
                  ),
                ),
              ),
              if (action != null)
                TextButton(
                  onPressed: () {
                    action.onPressed();
                    _close();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.inversePrimary,
                  ),
                  child: Text(action.label),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
