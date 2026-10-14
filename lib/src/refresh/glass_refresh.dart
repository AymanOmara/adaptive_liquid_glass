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
/// own layout), scales in with the pull and plays a haptic when armed.
/// While the refresh runs the content is held down by the spinner's room,
/// as `UIRefreshControl` holds a list, and it snaps back on SwiftUI's
/// spring once refresh completes; `BouncingScrollPhysics`
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

  /// The spinner's colour (the ring's on the Material path). Defaults to
  /// the system's.
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
  late final AnimationController _controller;

  /// The overscroll past the top, in pixels.
  double _pull = 0;

  /// The scrollable's signed overscroll past the top: positive while
  /// pulled, negative once scrolled into the content.
  final _overscroll = ValueNotifier<double>(0);

  bool _dragging = false;
  bool _armed = false;
  bool _refreshing = false;

  /// From the trigger until the snap-back settles: the content is held
  /// down by [RefreshMetrics.indicatorExtent] times the progress.
  bool _holding = false;

  /// The hold's current depth, in pixels; follows the snap-back spring.
  double get _hold =>
      _holding ? _controller.value * RefreshMetrics.indicatorExtent : 0;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _overscroll.value =
        notification.metrics.minScrollExtent - notification.metrics.pixels;
    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _dragging = true;
        // A post-refresh snap-back keeps going under a new drag; the
        // held content would jump otherwise.
        if (!_holding) _controller.stop();
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
    if (!_dragging || _holding) return;
    final progress = _pull / RefreshMetrics.triggerDistance;
    _controller.value = progress;
    final armed = progress >= 1;
    if (armed && !_armed && widget.enableFeedback) {
      HapticFeedback.mediumImpact();
    }
    _armed = armed;
  }

  void _endDrag() {
    if (_holding) return;
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
      _holding = true;
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
        _holding = false;
        _controller.value = 0;
      });
      return;
    }
    setState(() => _refreshing = false);
    _controller
        .animateWith(
          SpringSimulation(
            swiftUISpring(
              response: RefreshMetrics.snapResponse,
              dampingFraction: RefreshMetrics.snapDamping,
            ),
            _controller.value,
            0,
            0,
          ),
        )
        // The spring settles within its tolerance, not at 0; a value just
        // above 0 would leave the disk showing at its smallest scale.
        .then((_) {
          _holding = false;
          _controller.value = 0;
        });
  }

  // Created here, not lazily: one first read in dispose would create
  // its ticker on a deactivated element.
  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    _overscroll.dispose();
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

  /// The child is shifted down by what the hold adds beyond the pull
  /// (the release's bounce returns into the hold, not past it), clipped
  /// to the wrapper; while held, the spinner rides up with content
  /// scrolled into, as UIKit's content inset carries it.
  Widget _glass() => NotificationListener<ScrollNotification>(
    onNotification: _onScroll,
    child: AnimatedBuilder(
      animation: Listenable.merge([_controller, _overscroll]),
      builder: (context, _) {
        final overscroll = _overscroll.value;
        final shift = math.max(0.0, _hold - math.max(0.0, overscroll));
        return Stack(
          children: [
            ClipRect(
              clipBehavior: shift == 0 ? Clip.none : Clip.hardEdge,
              child: Transform.translate(
                offset: Offset(0, shift),
                child: widget.child,
              ),
            ),
            PositionedDirectional(
              top: _holding ? math.min(0.0, overscroll) : 0,
              start: 0,
              end: 0,
              height: RefreshMetrics.indicatorExtent,
              child: IgnorePointer(
                child: Center(
                  child: GlassRefreshIndicator(
                    progress: _controller.value,
                    refreshing: _refreshing,
                    color: widget.color,
                    semanticLabel: widget.semanticLabel,
                    mode: widget.mode,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
