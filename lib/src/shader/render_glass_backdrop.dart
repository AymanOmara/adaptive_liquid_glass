import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../group/entry_geometry.dart';
import '../group/glass_registry.dart';
import 'glass_backdrop.dart';
import 'glass_backdrop_config.dart';
import 'glass_backdrop_debug_frame.dart';
import 'glass_frame_uniforms.dart';
import 'glass_program.dart';
import 'glass_shape_uniform.dart';
import 'glass_texture_space.dart';

/// See [GlassBackdrop].
class RenderGlassBackdrop extends RenderProxyBox {
  /// Creates the render object.
  RenderGlassBackdrop({
    required GlassRegistry registry,
    required GlassBackdropConfig config,
    BackdropKey? backdropKey,
  }) : _registry = registry,
       _config = config,
       _backdropKey = backdropKey;

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<BackdropFilterLayer> _backdrop =
      LayerHandle<BackdropFilterLayer>();

  /// The last computed frame (null when nothing was drawable).
  GlassBackdropDebugFrame? debugLastFrame;

  GlassRegistry _registry;

  /// Members to draw.
  GlassRegistry get registry => _registry;
  set registry(GlassRegistry value) {
    if (identical(value, _registry)) return;
    if (attached) _registry.removeListener(markNeedsPaint);
    _registry = value;
    if (attached) _registry.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  GlassBackdropConfig _config;

  /// Drawing parameters.
  GlassBackdropConfig get config => _config;
  set config(GlassBackdropConfig value) {
    if (value == _config) return;
    _config = value;
    markNeedsPaint();
  }

  BackdropKey? _backdropKey;

  /// Shared capture key.
  BackdropKey? get backdropKey => _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry.addListener(markNeedsPaint);
    GlassProgram.instance.program.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _registry.removeListener(markNeedsPaint);
    GlassProgram.instance.program.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    _backdrop.layer = null;
    super.dispose();
  }

  GlassBackdropDebugFrame? _buildFrame() {
    final dpr = _config.devicePixelRatio;
    final toGlobal = getTransformTo(null);
    final fromGlobal = Matrix4.tryInvert(toGlobal);
    if (fromGlobal == null) return null;

    final drawn = collectEntryGeometry(_registry, toGlobal);
    for (final g in drawn) {
      g.entry.lastDrawnLocal = MatrixUtils.transformRect(fromGlobal, g.drawn);
    }
    if (drawn.isEmpty) return null;

    final union = drawn
        .map((g) => g.drawn)
        .reduce((a, b) => a.expandToInclude(b));
    final c = _config.constants;
    final shadow = [
      c.regular,
      c.clear,
      c.regularDark,
      c.clearDark,
    ].map((v) => v.shadowRadius).reduce(math.max);
    // The smooth union bulges up to mergeFactor × spacing past the shapes.
    final margin =
        shadow * 2 + math.max(1.0, c.mergeFactor) * _config.spacing + 2;
    final localBounds = MatrixUtils.transformRect(
      fromGlobal,
      union,
    ).inflate(margin);
    final origin = MatrixUtils.transformPoint(toGlobal, localBounds.topLeft);

    final shapes = mergeUnions([
      for (final g in drawn)
        GlassShapeUniform(
          rect: toTextureSpace(
            g.drawn,
            filterOriginGlobal: origin,
            devicePixelRatio: dpr,
          ),
          radius: g.radius * dpr,
          variant: g.entry.glass.variant,
          tint: g.entry.glass.tintColor,
          unionId: g.entry.unionId,
          cornerExponent: g.circularCorners ? 2.0 : null,
        ),
    ]);

    // One blur per group: the largest of the drawn shapes' sigmas, each
    // scaled down on shapes smaller than blurSizeRef and by the post-lens
    // share. Known limitation: a group mixing regular and clear (or large
    // and small) glass blurs every member as strongly as the strongest one.
    // The strongest member also sets the blur's aspect (blurAspectPower).
    var blurSigma = -1.0;
    var blurAspect = 1.0;
    for (final g in drawn) {
      final v = c.of(g.entry.glass.variant, _config.brightness);
      final s = composedBlurSigma(v, g.drawn.shortestSide / 2);
      if (s > blurSigma) {
        blurSigma = s;
        blurAspect = composedBlurAspect(v, g.drawn.size);
      }
    }

    Offset? touch;
    var glow = 0.0;
    for (final g in drawn) {
      final e = g.entry;
      final p = e.press.touch;
      final box = e.box;
      if (box == null) continue; // ghosts have no touch
      if (p != null && e.press.glow > glow) {
        glow = e.press.glow;
        touch = pointToTextureSpace(
          MatrixUtils.transformPoint(box.getTransformTo(null), p),
          filterOriginGlobal: origin,
          devicePixelRatio: dpr,
        );
      }
    }

    return GlassBackdropDebugFrame(
      GlassFrameUniforms(
        shapes: shapes,
        devicePixelRatio: dpr,
        lightAngle: _config.lightAngle,
        // Smooth-union radius: mergeFactor × spacing (physical px).
        smoothing: c.mergeFactor * _config.spacing * dpr,
        constants: c,
        brightness: _config.brightness,
        highContrast: _config.highContrast,
        opaqueColor: _config.opaqueColor,
        touch: touch,
        glow: glow,
      ),
      localBounds,
      origin,
      blurSigma,
      blurAspect,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final frame = _buildFrame();
    debugLastFrame = frame;
    final program = GlassProgram.instance.program.value;
    if (frame == null ||
        program == null ||
        !ui.ImageFilter.isShaderFilterSupported) {
      _clip.layer = null;
      super.paint(context, offset);
      return;
    }

    final shader = program.fragmentShader();
    final floats = packGlassUniforms(frame.uniforms);
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(kFirstUserFloat + i, floats[i]);
    }
    final backdrop = _backdrop.layer ??= BackdropFilterLayer();
    // The frost blur runs before the shader. The blur's sigma is in logical
    // px (the layer sits under the root dpr transform). Composing it keeps
    // FlutterFragCoord screen-global; uSize becomes the blurred input's size
    // (the screen grown right/bottom), so `px / uSize` still samples the
    // pixel under `px` (probe_test.dart). The shader returns premultiplied
    // colour that is transparent outside the shape except for the shadow,
    // and srcOver keeps the sharp backdrop there.
    final sigma = frame.blurSigma;
    final shaderFilter = ui.ImageFilter.shader(shader);
    backdrop
      ..filter = sigma > 0
          ? ui.ImageFilter.compose(
              outer: shaderFilter,
              inner: ui.ImageFilter.blur(
                sigmaX: sigma * frame.blurAspect,
                sigmaY: sigma / frame.blurAspect,
                tileMode: TileMode.clamp,
              ),
            )
          : shaderFilter
      ..blendMode = BlendMode.srcOver
      ..backdropKey = _backdropKey;
    _clip.layer = context.pushClipRect(
      needsCompositing,
      offset,
      frame.localBounds,
      (ctx, o) => ctx.pushLayer(backdrop, (_, _) {}, o),
      oldLayer: _clip.layer,
    );
    super.paint(context, offset);
  }
}
