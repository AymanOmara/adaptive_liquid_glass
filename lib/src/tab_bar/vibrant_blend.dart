import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'tab_bar_metrics.dart';
import 'tab_vibrancy_program.dart';
import 'vibrancy_kind.dart';

/// Paints [child] (tab glyphs, or the selected pill) vibrant, as iOS's tab
/// bar does: e.g. an untinted label pixel keeps the hue of the glass
/// behind it and takes the glyph's lightness (see [VibrancyKind]). [child] are rasterised and composited onto the
/// backdrop by `tab_vibrancy.frag`, so the glass must be Flutter's (shader
/// glass). Paints [child] normally when not [enabled], until the shader is
/// loaded, or when [child] needs compositing.
class VibrantBlend extends SingleChildRenderObjectWidget {
  /// Paints [child] vibrant when [enabled].
  const VibrantBlend({
    super.key,
    this.enabled = true,
    this.dark = false,
    this.kind = VibrancyKind.label,
    super.child,
  });

  /// What [child] is: a label, the selected tint or the selected pill
  /// (whose alpha is the pill's coverage).
  final VibrancyKind kind;

  /// Whether to blend; false paints the child normally.
  final bool enabled;

  /// Whether the glass is dark (iOS's dark vibrancy).
  final bool dark;

  @override
  RenderVibrantBlend createRenderObject(BuildContext context) {
    if (enabled) TabVibrancyProgram.instance.load();
    return RenderVibrantBlend(
      enabled: enabled,
      dark: dark,
      kind: kind,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderVibrantBlend renderObject,
  ) {
    if (enabled) TabVibrancyProgram.instance.load();
    renderObject
      ..enabled = enabled
      ..dark = dark
      ..kind = kind
      ..devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }
}

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
    markNeedsPaint();
  }

  final LayerHandle<OpacityLayer> _hidden = LayerHandle<OpacityLayer>();
  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<BackdropFilterLayer> _backdrop =
      LayerHandle<BackdropFilterLayer>();
  ui.Image? _image;

  ui.FragmentProgram? get _program => TabVibrancyProgram.instance.program.value;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    TabVibrancyProgram.instance.program.addListener(_programChanged);
  }

  @override
  void detach() {
    TabVibrancyProgram.instance.program.removeListener(_programChanged);
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
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  void _plain(PaintingContext context, Offset offset) {
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
    if (!_enabled || program == null || child.needsCompositing) {
      _plain(context, offset);
      return;
    }
    // Glyphs overhang their slots (the icon, the label's descenders).
    final pad = size.shortestSide;
    final bounds = (offset & size).inflate(pad);
    final dpr = _devicePixelRatio;
    // The glyphs, painted into a hidden layer and rasterised.
    final glyphs = OffsetLayer();
    _hidden.layer = context.pushOpacity(offset, 0, (context, offset) {
      context.pushLayer(
        glyphs,
        (context, offset) => context.paintChild(child, offset),
        offset,
      );
    }, oldLayer: _hidden.layer);
    // The opacity layer sits at [offset]: the glyphs lie at its origin.
    final image = glyphs.toImageSync(
      (Offset.zero & size).inflate(pad),
      pixelRatio: dpr,
    );
    _image?.dispose();
    _image = image;
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
    final shader = program.fragmentShader()
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
