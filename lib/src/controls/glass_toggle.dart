import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Switch;
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/effective_glass_mode.dart';
import '../core/glass_colors.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_system_colors.dart';
import 'control_metrics.dart';
import 'glass_thumb.dart';

/// iOS 26's switch: a capsule track whose thumb turns into a clear glass
/// lens while pressed or dragged.
///
/// ```dart
/// GlassToggle(value: wifi, onChanged: (v) => setState(() => wifi = v))
/// ```
///
/// Tap to flip it, or drag the thumb across. Null [onChanged] disables
/// it. Follows the reading direction; with Reduce Motion the thumb moves
/// without animating. On the Material path it is a Material 3 [Switch].
class GlassToggle extends StatefulWidget {
  /// Creates a toggle.
  const GlassToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.mode,
  });

  /// Whether it is on.
  final bool value;

  /// Called with the new value; the toggle shows [value] until the parent
  /// rebuilds it. If the parent keeps [value] unchanged, the thumb springs
  /// back to it. Null disables the toggle.
  final ValueChanged<bool>? onChanged;

  /// The track while on. Defaults to system green, or Material 3's colour
  /// on the Material path.
  final Color? activeColor;

  /// The rendering path for the thumb's lens; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassToggle> createState() => _GlassToggleState();
}

class _GlassToggleState extends State<GlassToggle>
    with TickerProviderStateMixin {
  /// 0 off, 1 on.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: widget.value ? 1 : 0,
  );

  /// 0 at rest, 1 held.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  /// A drag is in progress; its updates own `_position`.
  bool _dragging = false;

  bool get _enabled => widget.onChanged != null;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _rtl => Directionality.of(context) == TextDirection.rtl;

  double get _travel =>
      ControlMetrics.toggleWidth -
      ControlMetrics.toggleThumbWidth -
      ControlMetrics.thumbInset * 2;

  void _spring(AnimationController c, SpringDescription spring, double target) {
    if (_reduceMotion) {
      c.value = target;
    } else {
      c.animateWith(SpringSimulation(spring, c.value, target, c.velocity));
    }
  }

  @override
  void didUpdateWidget(GlassToggle old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _dragging = false; // The external value wins over any drag.
      _spring(_position, ControlMetrics.slide, widget.value ? 1 : 0);
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _press.dispose();
    super.dispose();
  }

  void _down() => _spring(_press, ControlMetrics.press, 1);

  void _up() => _spring(_press, ControlMetrics.press, 0);

  void _commit(bool value) {
    _spring(_position, ControlMetrics.slide, value ? 1 : 0);
    if (value != widget.value) {
      HapticFeedback.lightImpact();
      widget.onChanged?.call(value);
    }
    // If the parent rejects the change, spring back to the authoritative
    // value once this frame has had a chance to rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.value != value) _reconcile();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Springs the thumb back to [GlassToggle.value].
  void _reconcile() =>
      _spring(_position, ControlMetrics.slide, widget.value ? 1 : 0);

  void _drag(DragUpdateDetails d) {
    if (!_dragging) return;
    final dx = _rtl ? -d.delta.dx : d.delta.dx;
    _position.value = (_position.value + dx / _travel).clamp(0.0, 1.0);
  }

  /// Ends a drag; an abandoned one just reconciles.
  void _dragEnd() {
    if (!_dragging) {
      _reconcile();
      return;
    }
    _dragging = false;
    _commit(_position.value > 0.5);
  }

  /// A cancelled drag changes nothing.
  void _dragCancel() {
    _dragging = false;
    _reconcile();
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, mode) => mode == EffectiveGlassMode.material
        ? Switch(
            value: widget.value,
            onChanged: widget.onChanged,
            activeTrackColor: widget.activeColor,
          )
        : _glass(context),
  );

  Widget _glass(BuildContext context) {
    final on = CupertinoDynamicColor.resolve(
      widget.activeColor ?? GlassSystemColors.green,
      context,
    );
    final off = CupertinoDynamicColor.resolve(GlassColors.toggleOff, context);
    return Semantics(
      toggled: widget.value,
      enabled: _enabled,
      onTap: _enabled ? () => _commit(!widget.value) : null,
      child: FocusableActionDetector(
        enabled: _enabled,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _commit(!widget.value),
          ),
        },
        // The thumb turns to glass on touch, before the gesture is known.
        child: Listener(
          onPointerDown: _enabled ? (_) => _down() : null,
          onPointerUp: _enabled ? (_) => _up() : null,
          onPointerCancel: _enabled ? (_) => _up() : null,
          child: GestureDetector(
            excludeFromSemantics: true,
            onTap: _enabled ? () => _commit(!widget.value) : null,
            onHorizontalDragStart: _enabled ? (_) => _dragging = true : null,
            onHorizontalDragUpdate: _enabled ? _drag : null,
            onHorizontalDragEnd: _enabled ? (_) => _dragEnd() : null,
            onHorizontalDragCancel: _enabled ? _dragCancel : null,
            child: Opacity(
              opacity: _enabled ? 1 : 0.5,
              child: SizedBox(
                width: ControlMetrics.toggleWidth,
                height: ControlMetrics.toggleHeight,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_position, _press]),
                  builder: (context, _) {
                    final p = _position.value.clamp(0.0, 1.0);
                    final x = ControlMetrics.thumbInset + _travel * p;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: ShapeDecoration(
                              shape: const StadiumBorder(),
                              color: Color.lerp(off, on, p),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          start: x,
                          top: ControlMetrics.thumbInset,
                          bottom: ControlMetrics.thumbInset,
                          width: ControlMetrics.toggleThumbWidth,
                          child: GlassThumb(
                            pressed: _press.value,
                            color: GlassColors.thumb,
                            mode: widget.mode,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
