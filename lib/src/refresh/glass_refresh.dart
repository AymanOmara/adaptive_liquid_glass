import 'dart:math' as math;

import 'package:flutter/material.dart' show RefreshIndicator;
import 'package:flutter/physics.dart' show SpringSimulation;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import '../core/glass_render_mode.dart';
import '../core/swiftui_spring.dart';
import 'glass_refresh_indicator.dart';
import 'refresh_metrics.dart';

/// iOS 26's pull to refresh around any scrollable, like SwiftUI's
/// `.refreshable`.
///
/// ```dart
/// GlassRefresh(
///   onRefresh: () => reload(),
///   child: ListView(children: [...]),
/// )
/// ```
///
/// The indicator floats over the top of the content (the child keeps its
/// own layout), scales in with the pull, plays a haptic when armed, and
/// snaps back on SwiftUI's spring once refresh completes; `BouncingScrollPhysics`
/// is the natural fit, though clamping physics also work (the pull is then
/// tracked from the overscroll). On the Material path this is Material's
/// own [RefreshIndicator].
class GlassRefresh extends StatefulWidget {
  /// Creates the wrapper.
  const GlassRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.color,
    this.semanticLabel,
    this.enableFeedback = true,
    this.mode,
  });

  /// Called once per pull past the threshold; the indicator stays until
  /// the future completes.
  final Future<void> Function() onRefresh;

  /// The scrollable to wrap.
  final Widget child;

  /// The ring's / spinner's fill. Defaults to system blue.
  final Color? color;

  /// Announced while refreshing. Defaults to 'Refreshing'.
  final String? semanticLabel;

  /// Whether arming plays a haptic (`HapticFeedback.mediumImpact`).
  final bool enableFeedback;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  State<GlassRefresh> createState() => _GlassRefreshState();
}

class _GlassRefreshState extends State<GlassRefresh>
    with SingleTickerProviderStateMixin {
  /// The pull progress, 0 to 1+; also the snap-back animation's value.
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );

  /// The overscroll past the top, in pixels.
  double _pull = 0;

  bool _dragging = false;
  bool _armed = false;
  bool _refreshing = false;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _dragging = true;
        _controller.stop();
        _pull = math.max(
          0,
          notification.metrics.minScrollExtent - notification.metrics.pixels,
        );
      }
    } else if (notification is ScrollUpdateNotification) {
      if (notification.dragDetails == null && _dragging) {
        _dragging = false;
        _endDrag();
      } else {
        _pull = math.max(
          0,
          notification.metrics.minScrollExtent - notification.metrics.pixels,
        );
      }
    } else if (notification is OverscrollNotification) {
      // Clamping physics never move the pixels past the extent; the
      // pull arrives as overscroll instead (negative at the top).
      _pull = math.max(0, _pull - notification.overscroll);
    } else if (notification is ScrollEndNotification) {
      if (_dragging) {
        _dragging = false;
        _endDrag();
      }
    }
    _updateProgress();
    return false;
  }

  /// While dragging and not refreshing, the pull drives the progress and
  /// the arm; a haptic plays the first time it arms.
  void _updateProgress() {
    if (!_dragging || _refreshing) return;
    final progress = _pull / RefreshMetrics.triggerDistance;
    _controller.value = progress;
    final armed = progress >= 1;
    if (armed && !_armed && widget.enableFeedback) {
      HapticFeedback.mediumImpact();
    }
    _armed = armed;
  }

  void _endDrag() {
    if (_armed) {
      _trigger();
    } else if (!_refreshing) {
      _snapBack();
    }
  }

  /// Arms the refresh: the indicator spins at full pull until
  /// [GlassRefresh.onRefresh] completes.
  void _trigger() {
    setState(() {
      _refreshing = true;
      _armed = false;
      _controller.value = 1;
    });
    widget.onRefresh().whenComplete(() {
      if (mounted) _snapBack();
    });
  }

  /// Springs the progress back to 0, ending the refresh.
  void _snapBack() {
    if (_reduceMotion) {
      setState(() {
        _refreshing = false;
        _controller.value = 0;
      });
      return;
    }
    setState(() => _refreshing = false);
    _controller.animateWith(
      SpringSimulation(
        swiftUISpring(
          response: RefreshMetrics.snapResponse,
          dampingFraction: RefreshMetrics.snapDamping,
        ),
        _controller.value,
        0,
        0,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    mode: widget.mode,
    builder: (context, effective) => effective == EffectiveGlassMode.material
        ? RefreshIndicator(
            onRefresh: widget.onRefresh,
            color: widget.color,
            semanticsLabel: widget.semanticLabel,
            child: widget.child,
          )
        : _glass(),
  );

  Widget _glass() => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: Stack(
      children: [
        widget.child,
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          height: RefreshMetrics.indicatorExtent,
          child: IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => GlassRefreshIndicator(
                  progress: _controller.value,
                  refreshing: _refreshing,
                  color: widget.color,
                  semanticLabel: widget.semanticLabel,
                  mode: widget.mode,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
