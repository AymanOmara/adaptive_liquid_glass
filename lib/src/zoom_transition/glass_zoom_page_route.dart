import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../adaptive/glass_adaptive.dart';
import '../core/glass_render_mode.dart';
import '../core/ios_page_text.dart';
import 'glass_zoom_source.dart';
import 'zoom_drag_dismiss.dart';
import 'zoom_transition_metrics.dart';

/// Pushes [builder]'s page growing out of the [GlassZoomSource] with
/// [sourceId] in [namespace], like SwiftUI's
/// `.navigationTransition(.zoom(sourceID:in:))`, and returns what it pops
/// with.
///
/// The page shrinks back into the source on pop and, with
/// [dragToDismiss], when dragged down or swiped from the leading edge.
/// Under Reduce Motion it cross-fades; on the Material path
/// ([GlassAdaptive]) it zooms with Material's container-transform timing
/// and does not drag.
Future<T?> pushGlassZoom<T>(
  BuildContext context, {
  required Object sourceId,
  Object? namespace,
  required WidgetBuilder builder,
  Color? backgroundColor,
  bool dragToDismiss = true,
  GlassRenderMode? mode,
  bool useRootNavigator = false,
  RouteSettings? settings,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push(
    GlassZoomPageRoute<T>(
      builder: builder,
      sourceId: sourceId,
      namespace: namespace,
      backgroundColor: backgroundColor,
      dragToDismiss: dragToDismiss,
      mode: mode,
      settings: settings,
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
    ),
  );
}

/// The route [pushGlassZoom] pushes; use it directly with named routes
/// (`onGenerateRoute`).
class GlassZoomPageRoute<T> extends PageRoute<T> {
  /// Creates the route.
  GlassZoomPageRoute({
    required this.builder,
    required this.sourceId,
    this.namespace,
    this.backgroundColor,
    this.dragToDismiss = true,
    this.mode,
    this.capturedThemes,
    super.settings,
  });

  /// Builds the page, full screen (it handles its own safe area).
  final WidgetBuilder builder;

  /// The [GlassZoomSource.id] the page grows out of.
  final Object sourceId;

  /// The [GlassZoomSource.namespace] [sourceId] is in.
  final Object? namespace;

  /// The page's background; defaults to the system background.
  final Color? backgroundColor;

  /// Whether a downward drag or a leading-edge swipe dismisses the page
  /// (glass path only).
  final bool dragToDismiss;

  /// Forces a path; null follows [GlassAdaptive].
  final GlassRenderMode? mode;

  /// Themes captured from the pushing context; null uses the navigator's.
  final CapturedThemes? capturedThemes;

  bool _material = false;
  GlassZoomSourceState? _source;
  Rect? _sourceRect;
  BorderRadius _sourceRadius = BorderRadius.zero;
  ui.Image? _snapshot;
  bool _hidSource = false;

  /// Where a drag left the page when it let go to dismiss; the pop
  /// shrinks from here instead of the full screen.
  ZoomFrame? dismissFrom;

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => _material
      ? ZoomTransitionMetrics.materialDuration
      : ZoomTransitionMetrics.duration;

  @override
  Duration get reverseTransitionDuration => _material
      ? ZoomTransitionMetrics.materialReverseDuration
      : ZoomTransitionMetrics.reverseDuration;

  @override
  void install() {
    // Before super.install, which builds the controller from the
    // durations above.
    _material = !GlassAdaptive.usesGlass(navigator!.context, mode: mode);
    super.install();
    animation!.addStatusListener(_onStatus);
  }

  RenderBox? get _overlayBox =>
      navigator?.overlay?.context.findRenderObject() as RenderBox?;

  void _measure() {
    final overlay = _overlayBox;
    final source = _source;
    if (overlay == null || source == null || !source.mounted) return;
    _sourceRect = source.rectIn(overlay) ?? _sourceRect;
    _sourceRadius = source.radius;
  }

  @override
  TickerFuture didPush() {
    _source = GlassZoomSourceState.lookup(namespace, sourceId);
    _measure();
    if (_source != null && _sourceRect != null) {
      _snapshot = _source!.snapshot();
      _source!.hide();
      _hidSource = true;
    }
    return super.didPush();
  }

  @override
  bool didPop(T? result) {
    // The source may have moved (scrolled) since the push.
    _measure();
    return super.didPop(result);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) _showSource();
  }

  void _showSource() {
    if (!_hidSource) return;
    _hidSource = false;
    _source?.show();
  }

  @override
  void dispose() {
    _showSource();
    _snapshot?.dispose();
    _snapshot = null;
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final background = CupertinoDynamicColor.resolve(
      backgroundColor ?? CupertinoColors.systemBackground,
      context,
    );
    final page = Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      namesRoute: true,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: background.computeLuminance() > 0.5
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: ColoredBox(
          color: background,
          child: iosPageText(Builder(builder: builder)),
        ),
      ),
    );
    return capturedThemes?.wrap(page) ?? page;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      // Reduce Motion: a cross-fade at full size.
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    }
    return ZoomDragDismiss(
      route: this,
      enabled: dragToDismiss && !_material,
      child: child,
    );
  }

  /// The page's frame and corners at its source, in overlay coordinates;
  /// null when no source was found.
  ZoomFrame? sourceFrame(Size screen) {
    final rect = _sourceRect;
    if (rect == null) return null;
    return ZoomFrame.aspectFill(rect, screen, _sourceRadius);
  }

  /// The snapshot of the source cross-fading into the page.
  ui.Image? get snapshot => _snapshot;

  /// Whether this route runs the Material container transform.
  bool get isMaterial => _material;
}
