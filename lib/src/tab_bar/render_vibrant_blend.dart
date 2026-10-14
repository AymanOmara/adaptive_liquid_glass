import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../shader/raster_snapshot_gate.dart';
import '../shader/reused_shader.dart';
import 'tab_bar_metrics.dart';
import 'tab_vibrancy_program.dart';
import 'vibrancy_kind.dart';
import 'vibrant_blend.dart';

/// See [VibrantBlend].
class RenderVibrantBlend extends RenderProxyBox {
  /// Creates the render object.
  RenderVibrantBlend({
    required bool enabled,
    required bool dark,
    required VibrancyKind kind,
    required double devicePixelRatio,
  }) : _enabled = enabled,
       _dark = dark,
       _kind = kind,
       _devicePixelRatio = devicePixelRatio;

  bool _enabled;

  /// See [VibrantBlend.enabled].
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  bool _dark;

  /// See [VibrantBlend.dark].
  bool get dark => _dark;
  set dark(bool value) {
    if (value == _dark) return;
    _dark = value;
    markNeedsPaint();
  }

  VibrancyKind _kind;

  /// See [VibrantBlend.kind].
  VibrancyKind get kind => _kind;
  set kind(VibrancyKind value) {
    if (value == _kind) return;
    _kind = value;
    markNeedsPaint();
  }

  double _devicePixelRatio;

  /// The screen's pixel ratio, for the glyph image.
  double get devicePixelRatio => _devicePixelRatio;
  set devicePixelRatio(double value) {
    if (value == _devicePixelRatio) return;
    _devicePixelRatio = value;
    _stale = true;
    markNeedsPaint();
  }

  final LayerHandle<OpacityLayer> _hidden = LayerHandle<OpacityLayer>();
  final LayerHandle<OffsetLayer> _glyphs = LayerHandle<OffsetLayer>();
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<BackdropFilterLayer> _backdrop =
      LayerHandle<BackdropFilterLayer>();
  ui.Image? _image;
  // One shader, re-pointed at each new glyph image: a shader per paint
  // kept every replaced glyph image alive until garbage collection.
  final _shader = reusedFragmentShader();

  // Whether [_image] must be rasterised again: the glyphs are reused while
  // only the backdrop or this box's position changes (a lens or the bar
  // moving over them), as rasterising every frame drops frames.
  bool _stale = true;
  Size? _imageSize;

  @override
  void markNeedsPaint() {
    // A repaint of the child reaches here (it is no repaint boundary).
    _stale = true;
    super.markNeedsPaint();
  }

  ui.FragmentProgram? get _program => TabVibrancyProgram.instance.program.value;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    TabVibrancyProgram.instance.program.addListener(_programChanged);
    RasterSnapshotGate.instance.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    TabVibrancyProgram.instance.program.removeListener(_programChanged);
    RasterSnapshotGate.instance.removeListener(markNeedsPaint);
    super.detach();
  }

  void _programChanged() {
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _enabled && _program != null;

  @override
  void dispose() {
    _hidden.layer = null;
    _clip.layer = null;
    _backdrop.layer = null;
    _shader.clear();
    _image?.dispose();
    _image = null;
    _glyphs.layer = null;
    super.dispose();
  }

  void _plain(PaintingContext context, Offset offset) {
    _stale = true;
    _hidden.layer = null;
    _clip.layer = null;
    _backdrop.layer = null;
    super.paint(context, offset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    final program = _program;
    if (child == null) return;
    // The glyph image is a raster snapshot: none before the first frame
    // reaches the screen or in the background (see RasterSnapshotGate).
    if (!_enabled ||
        program == null ||
        child.needsCompositing ||
        !RasterSnapshotGate.instance.isOpen) {
      _plain(context, offset);
      return;
    }
    // Glyphs overhang their slots (the icon, the label's descenders).
    final pad = size.shortestSide;
    final bounds = (offset & size).inflate(pad);
    final dpr = _devicePixelRatio;
    // The glyphs, painted into a hidden layer and rasterised.
    var image = _image;
    if (image == null || _stale || _imageSize != size) {
      final glyphs = _glyphs.layer = OffsetLayer();
      _hidden.layer = context.pushOpacity(offset, 0, (context, offset) {
        context.pushLayer(
          glyphs,
          (context, offset) => context.paintChild(child, offset),
          offset,
        );
      }, oldLayer: _hidden.layer);
      // The opacity layer sits at [offset]: the glyphs lie at its origin.
      image = glyphs.toImageSync(
        (Offset.zero & size).inflate(pad),
        pixelRatio: dpr,
      );
      _image?.dispose();
      _image = image;
      _imageSize = size;
      _stale = false;
    }
    final origin = localToGlobal(Offset(-pad, -pad)) * dpr;
    final (a, b, c) = switch (_kind) {
      VibrancyKind.tint => (
        TabBarMetrics.tintVibrancyGain,
        _dark
            ? TabBarMetrics.tintVibrancyReferenceDark
            : TabBarMetrics.tintVibrancyReference,
        0.0,
      ),
      VibrancyKind.pill =>
        _dark
            ? (
                TabBarMetrics.pillVibrancyScaleDark,
                TabBarMetrics.pillVibrancyGammaDark,
                TabBarMetrics.pillVibrancyLiftDark,
              )
            : (
                TabBarMetrics.pillVibrancyScale,
                TabBarMetrics.pillVibrancyGamma,
                0.0,
              ),
      VibrancyKind.label =>
        _dark
            ? (
                TabBarMetrics.vibrancyLightnessGainDark,
                TabBarMetrics.vibrancyReferenceDark,
                TabBarMetrics.vibrancyChromaGainDark,
              )
            : (
                TabBarMetrics.vibrancyLightnessGain,
                TabBarMetrics.vibrancyReference,
                TabBarMetrics.vibrancyChromaGain,
              ),
    };
    final shader = _shader.of(program)
      ..setFloat(2, origin.dx)
      ..setFloat(3, origin.dy)
      ..setFloat(4, bounds.width * dpr)
      ..setFloat(5, bounds.height * dpr)
      ..setFloat(6, a)
      ..setFloat(7, b)
      ..setFloat(8, c)
      ..setFloat(9, _kind.index.toDouble())
      ..setImageSampler(1, image);
    final backdrop = _backdrop.layer ??= BackdropFilterLayer();
    backdrop.filter = ui.ImageFilter.shader(shader);
    _clip.layer = context.pushClipRect(
      true,
      Offset.zero,
      bounds,
      (context, _) => context.pushLayer(backdrop, (_, _) {}, Offset.zero),
      oldLayer: _clip.layer,
    );
  }
}
