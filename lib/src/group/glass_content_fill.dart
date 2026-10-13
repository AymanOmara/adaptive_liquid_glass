import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'concentric_scope.dart';
import 'glass_entry.dart';
import 'glass_group_scope.dart';
import 'glass_registry.dart';

/// A system fill drawn by native glass inside the enclosing `LiquidGlass`,
/// as SwiftUI content of its `.glassEffect` view: SwiftUI gives such fills
/// the glass's vibrancy (iOS 26's tab bar draws its selected pill this
/// way), which Flutter, unable to see UIKit glass, cannot. Paints nothing
/// itself; only the native path draws it.
class GlassContentFill extends SingleChildRenderObjectWidget {
  /// Fills this box with [style] at [opacity], as a capsule.
  const GlassContentFill({
    super.key,
    this.style = GlassFillStyle.tertiary,
    this.opacity = 1,
    super.child,
  });

  /// The system fill.
  final GlassFillStyle style;

  /// The fill's opacity.
  final double opacity;

  @override
  RenderGlassContentFill createRenderObject(BuildContext context) =>
      RenderGlassContentFill(
        entry: ConcentricScope.maybeOf(context),
        registry: GlassGroupScope.maybeOf(context)?.registry,
        style: style,
        opacity: opacity,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassContentFill renderObject,
  ) {
    renderObject
      ..entry = ConcentricScope.maybeOf(context)
      ..registry = GlassGroupScope.maybeOf(context)?.registry
      ..style = style
      ..opacity = opacity;
  }
}

/// SwiftUI's system fills (`FillShapeStyle` and its levels, lightest
/// last), and plain lighten and darken.
enum GlassFillStyle {
  /// `.fill`.
  primary,

  /// `.fill.secondary`.
  secondary,

  /// `.fill.tertiary`.
  tertiary,

  /// `.fill.quaternary`.
  quaternary,

  /// White added to the glass beneath (`.plusLighter`): lifts every
  /// channel by the same amount, keeping the backdrop's colour.
  lighten,

  /// Black subtracted from the glass beneath (`.plusDarker`): lowers every
  /// channel by the same amount, keeping the backdrop's colour.
  darken,

  /// A 1-pt white ring along the capsule, added to the glass beneath
  /// (`.plusLighter`): a brighter rim than UIKit's own.
  lightenRim,
}

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
