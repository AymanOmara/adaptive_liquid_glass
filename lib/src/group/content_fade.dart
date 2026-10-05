import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Fades member content during morphs. Fixed tree depth (no remount when a
/// fade ends), no rebuild per tick, and no layer outside a fade.
class ContentFade extends SingleChildRenderObjectWidget {
  /// Creates the fade.
  const ContentFade({super.key, required this.opacity, super.child});

  /// The content's opacity over the morph, from the member's entry.
  final ValueListenable<double> opacity;

  @override
  RenderContentFade createRenderObject(BuildContext context) =>
      RenderContentFade(opacity);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderContentFade renderObject,
  ) => renderObject.opacity = opacity;
}

/// See [ContentFade].
class RenderContentFade extends RenderProxyBox {
  /// Creates the fade.
  RenderContentFade(this._opacity) : _alpha = _alphaOf(_opacity.value);

  static int _alphaOf(double v) => (v.clamp(0.0, 1.0) * 255).round();

  ValueListenable<double> _opacity;
  set opacity(ValueListenable<double> value) {
    if (identical(value, _opacity)) return;
    if (attached) _opacity.removeListener(_update);
    _opacity = value;
    if (attached) _opacity.addListener(_update);
    _update();
  }

  int _alpha;

  bool get _composites => child != null && _alpha > 0 && _alpha < 255;

  void _update() {
    final a = _alphaOf(_opacity.value);
    if (a == _alpha) return;
    final was = _composites;
    final wasVisible = _alpha > 0;
    _alpha = a;
    if (was != _composites) markNeedsCompositingBitsUpdate();
    if (wasVisible != (_alpha > 0)) markNeedsSemanticsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _composites;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _opacity.addListener(_update);
    _update();
  }

  @override
  void detach() {
    _opacity.removeListener(_update);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _alpha == 0) {
      layer = null;
      return;
    }
    if (_alpha == 255) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushOpacity(
      offset,
      _alpha,
      super.paint,
      oldLayer: layer as OpacityLayer?,
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_alpha > 0) super.visitChildrenForSemantics(visitor);
  }
}
