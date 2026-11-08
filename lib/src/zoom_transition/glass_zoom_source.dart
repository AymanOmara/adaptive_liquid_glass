import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks the widget a [GlassZoomPageRoute] grows out of and shrinks back
/// into, like SwiftUI's `.matchedTransitionSource(id:in:)`.
///
/// The route finds its source by [id] within [namespace]; when several
/// mounted sources share both, the last mounted wins. The source hides
/// while its route is on screen, as the page has taken its place.
class GlassZoomSource extends StatefulWidget {
  /// Creates a zoom source.
  const GlassZoomSource({
    super.key,
    required this.id,
    this.namespace,
    this.borderRadius = BorderRadius.zero,
    required this.child,
  });

  /// What a route names to zoom from this widget.
  final Object id;

  /// Scopes [id], like SwiftUI's `@Namespace`; null is the global one.
  final Object? namespace;

  /// The source's corner radius, which the page's corners start from.
  final BorderRadiusGeometry borderRadius;

  /// The source's content.
  final Widget child;

  @override
  State<GlassZoomSource> createState() => GlassZoomSourceState();
}

/// A mounted [GlassZoomSource], as the route sees it.
class GlassZoomSourceState extends State<GlassZoomSource> {
  static final Map<(Object?, Object), List<GlassZoomSourceState>> _sources =
      {};

  /// The last mounted source with [id] in [namespace], if any.
  static GlassZoomSourceState? lookup(Object? namespace, Object id) {
    final list = _sources[(namespace, id)];
    return list == null || list.isEmpty ? null : list.last;
  }

  final GlobalKey _boundary = GlobalKey();
  late (Object?, Object) _key;
  int _hidden = 0;

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void didUpdateWidget(GlassZoomSource oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.namespace != widget.namespace) {
      _unregister();
      _register();
    }
  }

  @override
  void dispose() {
    _unregister();
    super.dispose();
  }

  void _register() {
    _key = (widget.namespace, widget.id);
    (_sources[_key] ??= []).add(this);
  }

  void _unregister() {
    final list = _sources[_key];
    list?.remove(this);
    if (list != null && list.isEmpty) _sources.remove(_key);
  }

  /// The source's frame in [ancestor]'s coordinates, or null when it is
  /// not laid out.
  Rect? rectIn(RenderBox ancestor) {
    final box = _boundary.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return MatrixUtils.transformRect(
      box.getTransformTo(ancestor),
      Offset.zero & box.size,
    );
  }

  /// The source's corner radius, resolved.
  BorderRadius get radius =>
      widget.borderRadius.resolve(Directionality.maybeOf(context));

  /// A picture of the source as it last painted, or null.
  ui.Image? snapshot() {
    final box = _boundary.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || box.debugNeedsPaint) return null;
    try {
      return box.toImageSync(
        pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
      );
    } on Object {
      return null;
    }
  }

  /// Hides the source (counted, so overlapping routes nest).
  void hide() {
    if (!mounted) return;
    setState(() => _hidden++);
  }

  /// Undoes one [hide].
  void show() {
    if (!mounted || _hidden == 0) return;
    setState(() => _hidden--);
  }

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: _hidden > 0 ? 0 : 1,
    child: RepaintBoundary(key: _boundary, child: widget.child),
  );
}
