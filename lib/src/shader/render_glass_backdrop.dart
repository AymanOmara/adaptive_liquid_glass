import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../group/glass_registry.dart';
import '../layer/glass_layer.dart';
import 'glass_backdrop.dart';
import 'glass_backdrop_config.dart';
import 'glass_backdrop_debug_frame.dart';
import 'glass_frame_uniforms.dart';
import 'glass_group_frame.dart';
import 'glass_program.dart';
import 'reused_shader.dart';

/// See [GlassBackdrop].
class RenderGlassBackdrop extends RenderProxyBox {
  /// Creates the render object.
  RenderGlassBackdrop({
    required GlassRegistry registry,
    required GlassBackdropConfig config,
    BackdropKey? backdropKey,
    GlassLayer? sharedLayer,
  }) : _registry = registry,
       _config = config,
       _backdropKey = backdropKey,
       _sharedLayer = sharedLayer;

  final LayerHandle<ClipRectLayer> _clip = LayerHandle<ClipRectLayer>();
  final LayerHandle<BackdropFilterLayer> _backdrop =
      LayerHandle<BackdropFilterLayer>();
  final _shader = reusedFragmentShader();

  /// The last computed frame (null when nothing was drawable).
  GlassBackdropDebugFrame? debugLastFrame;

  GlassRegistry _registry;

  /// Members to draw.
  GlassRegistry get registry => _registry;
  set registry(GlassRegistry value) {
    if (identical(value, _registry)) return;
    if (attached) _registry.removeListener(_onChange);
    _registry = value;
    if (attached) _registry.addListener(_onChange);
    _onChange();
  }

  GlassBackdropConfig _config;

  /// Drawing parameters.
  GlassBackdropConfig get config => _config;
  set config(GlassBackdropConfig value) {
    if (value == _config) return;
    _config = value;
    _onChange();
  }

  BackdropKey? _backdropKey;

  /// Shared capture key.
  BackdropKey? get backdropKey => _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  GlassLayer? _sharedLayer;

  /// The route's shared glass layer, which then draws this group's glass
  /// and composites its content (the child, a repaint boundary) after the
  /// route; null draws them here.
  GlassLayer? get sharedLayer => _sharedLayer;
  set sharedLayer(GlassLayer? value) {
    if (identical(value, _sharedLayer)) return;
    if (attached) _sharedLayer?.removeClient(this);
    _sharedLayer = value;
    if (attached) _sharedLayer?.addClient(this);
    sharedTransform = null;
    markNeedsPaint();
  }

  /// The global transform the shared layer last drew this group with.
  Matrix4? sharedTransform;

  /// Repaints whoever draws the glass.
  void _onChange() {
    final layer = _sharedLayer;
    if (layer == null) {
      markNeedsPaint();
    } else {
      layer.markNeedsPaint();
    }
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _registry.addListener(_onChange);
    GlassProgram.instance.program.addListener(markNeedsPaint);
    _sharedLayer?.addClient(this);
  }

  @override
  void detach() {
    _sharedLayer?.removeClient(this);
    _registry.removeListener(_onChange);
    GlassProgram.instance.program.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clip.layer = null;
    _backdrop.layer = null;
    _shader.clear();
    super.dispose();
  }

  GlassBackdropDebugFrame? _buildFrame() => computeGroupFrame(
    registry: _registry,
    config: _config,
    toGlobal: getTransformTo(null),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    final layer = _sharedLayer;
    if (layer != null) {
      // The layer paints our glass and composites our content after the
      // route. Moved without a registry change (an ancestor re-laid us
      // out): refresh the layer one frame late, as RenderGlassMember does.
      _clip.layer = null;
      assert(child == null || child!.isRepaintBoundary);
      final t = getTransformTo(null);
      if (sharedTransform != null && sharedTransform != t) {
        layer.markNeedsPaintAfterFrame();
      }
      return;
    }
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

    final shader = _shader.of(program);
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
