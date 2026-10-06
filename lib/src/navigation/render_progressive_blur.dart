import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../shader/glass_uniforms.dart' show kFirstUserFloat;
import 'progressive_blur_uniforms.dart';

/// Blurs what lies behind it, strongest at its top edge and sharp at its
/// bottom, with two passes of `progressive_blur.frag` as a backdrop
/// filter.
///
/// The region is read at paint time: an ancestor that moves it (a scroll,
/// a route transition) repaints rather than rebuilds it.
class RenderProgressiveBlur extends RenderProxyBox {
  /// Creates the render object.
  RenderProgressiveBlur({
    required ui.FragmentProgram program,
    required double maxSigma,
    required double falloff,
    required double devicePixelRatio,
  }) : _program = program,
       _maxSigma = maxSigma,
       _falloff = falloff,
       _devicePixelRatio = devicePixelRatio;

  ui.FragmentProgram _program;
  ui.FragmentShader? _horizontal;
  ui.FragmentShader? _vertical;
  double _maxSigma;
  double _falloff;
  double _devicePixelRatio;
  final LayerHandle<BackdropFilterLayer> _backdrop =
      LayerHandle<BackdropFilterLayer>();
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();

  /// The compiled shader.
  set program(ui.FragmentProgram value) {
    if (identical(value, _program)) return;
    _program = value;
    _disposeShaders();
    markNeedsPaint();
  }

  /// The sigma at the top edge, logical px.
  set maxSigma(double value) {
    if (value == _maxSigma) return;
    _maxSigma = value;
    markNeedsPaint();
  }

  /// The gradient's gamma: above 1 keeps the blur strong further down.
  set falloff(double value) {
    if (value == _falloff) return;
    _falloff = value;
    markNeedsPaint();
  }

  /// Logical to device px.
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final h = _horizontal ??= _program.fragmentShader();
    final v = _vertical ??= _program.fragmentShader();
    // The shader's FlutterFragCoord is screen-global device px
    // (`kGlassTextureSpace`).
    final origin = localToGlobal(Offset.zero);
    _configure(h, 0, origin);
    _configure(v, 1, origin);
    final backdrop = _backdrop.layer ??= BackdropFilterLayer();
    backdrop.filter = ui.ImageFilter.compose(
      outer: ui.ImageFilter.shader(v),
      inner: ui.ImageFilter.shader(h),
    );
    // The clip bounds what the filter writes; it otherwise reaches up to
    // the nearest ancestor clip.
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      (ctx, o) => ctx.pushLayer(backdrop, super.paint, o),
      oldLayer: _clip.layer,
    );
  }

  void _configure(ui.FragmentShader shader, double axis, Offset origin) {
    final floats = progressiveBlurUniforms(
      origin: origin,
      size: size,
      devicePixelRatio: _devicePixelRatio,
      maxSigma: _maxSigma,
      falloff: _falloff,
      axis: axis,
    );
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(kFirstUserFloat + i, floats[i]);
    }
  }

  void _disposeShaders() {
    _horizontal?.dispose();
    _vertical?.dispose();
    _horizontal = _vertical = null;
  }

  @override
  void dispose() {
    _disposeShaders();
    _backdrop.layer = null;
    _clip.layer = null;
    super.dispose();
  }
}
