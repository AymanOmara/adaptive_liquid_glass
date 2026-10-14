import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'glass_entry.dart';
import 'glass_fill_style.dart';
import 'glass_registry.dart';

/// See [GlassContentFill].
class RenderGlassContentFill extends RenderProxyBox {
  /// Creates the render object.
  RenderGlassContentFill({
    required GlassEntry? entry,
    required this.registry,
    required GlassFillStyle style,
    required double opacity,
  }) : _entry = entry,
       _style = style,
       _opacity = opacity;

  /// The registry to refresh when the fill changes.
  GlassRegistry? registry;

  GlassEntry? _entry;

  /// The enclosing glass.
  GlassEntry? get entry => _entry;
  set entry(GlassEntry? value) {
    if (value == _entry) return;
    if (attached) _entry?.fills.remove(this);
    _entry = value;
    if (attached) _entry?.fills.add(this);
    _changed();
  }

  GlassFillStyle _style;

  /// See [GlassContentFill.style].
  GlassFillStyle get style => _style;
  set style(GlassFillStyle value) {
    if (value == _style) return;
    _style = value;
    _changed();
  }

  double _opacity;

  /// See [GlassContentFill.opacity].
  double get opacity => _opacity;
  set opacity(double value) {
    if (value == _opacity) return;
    _opacity = value;
    _changed();
  }

  Matrix4? _lastTransform;

  void _changed() {
    if (!attached) return;
    final r = registry;
    if (r == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached) r.markNeedsPaint();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _entry?.fills.add(this);
    _changed();
  }

  @override
  void detach() {
    _entry?.fills.remove(this);
    registry?.markNeedsPaint();
    super.detach();
  }

  @override
  void performLayout() {
    final old = hasSize ? size : null;
    super.performLayout();
    if (old != size) _changed();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // Moved (the pill slides with the selection): push the new geometry.
    final t = getTransformTo(null);
    if (_lastTransform != t) _changed();
    _lastTransform = t;
  }
}
