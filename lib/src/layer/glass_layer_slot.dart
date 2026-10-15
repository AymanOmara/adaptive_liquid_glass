import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../shader/glass_frame_uniforms.dart';
import '../shader/glass_group_frame.dart';
import '../shader/glass_program.dart';
import '../shader/render_glass_backdrop.dart';
import '../shader/reused_shader.dart';
import 'glass_layer.dart';
import 'glass_layer_plan.dart';
import 'paint_chain.dart';

/// A group's place in its route's shared glass layer: the overlay child of
/// the group's `OverlayPortal`, painted after the whole route. The first
/// live slot of a layer paints every group's glass and then their content.
class GlassLayerSlot extends LeafRenderObjectWidget {
  /// Creates a slot.
  const GlassLayerSlot({super.key, required this.layer});

  /// The route's layer.
  final GlassLayer layer;

  @override
  RenderGlassLayerSlot createRenderObject(BuildContext context) =>
      RenderGlassLayerSlot(layer);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassLayerSlot renderObject,
  ) => renderObject.glassLayer = layer;
}

class _Client {
  _Client(this.box, this.chain, this.toGlobal);
  final RenderGlassBackdrop box;
  final PaintChain chain;
  final Matrix4 toGlobal;
}

/// See [GlassLayerSlot].
class RenderGlassLayerSlot extends RenderBox {
  /// Creates the slot.
  RenderGlassLayerSlot(this._layer);

  GlassLayer _layer;

  /// The route's layer.
  GlassLayer get glassLayer => _layer;
  set glassLayer(GlassLayer value) {
    if (identical(value, _layer)) return;
    if (attached) _layer.removeSlot(this);
    _layer = value;
    if (attached) _layer.addSlot(this);
    markNeedsPaint();
  }

  // One shader per pass: a filter reads its shader's uniforms when the
  // frame is rasterised, not when it is made, so passes cannot share one.
  final List<ReusedShader<ui.FragmentProgram, ui.FragmentShader>> _shaders = [];
  final List<BackdropKey> _keys = [];

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.hasBoundedWidth && constraints.hasBoundedHeight
      ? constraints.biggest
      : constraints.smallest;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _layer.addSlot(this);
    GlassProgram.instance.program.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    GlassProgram.instance.program.removeListener(markNeedsPaint);
    _layer.removeSlot(this);
    super.detach();
  }

  @override
  void dispose() {
    for (final s in _shaders) {
      s.clear();
    }
    super.dispose();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!identical(_layer.painter, this)) return;
    final stop = Set<RenderObject>.identity()
      ..add(this)
      ..addAll(ancestorsOf(this));
    final fromGlobal = Matrix4.tryInvert(getTransformTo(null));
    if (fromGlobal == null) return;

    final clients = <Object, _Client>{};
    final inputs = <LayerGroupInput>[];
    final contentOnly = <_Client>[];
    for (final box in _layer.clients) {
      if (!box.attached || !box.hasSize || box.child == null) continue;
      final chain = describePaintChain(box, stop);
      if (!chain.painted || chain.opacity <= 0) continue;
      final toGlobal = box.getTransformTo(null);
      final client = _Client(box, chain, toGlobal);
      clients[box] = client;
      box.sharedTransform = toGlobal;
      final frame = computeGroupFrame(
        registry: box.registry,
        config: box.config,
        toGlobal: toGlobal,
      );
      box.debugLastFrame = frame;
      if (frame == null) {
        contentOnly.add(client);
        continue;
      }
      inputs.add(
        LayerGroupInput(
          id: box,
          order: chain.order,
          frame: frame,
          bounds: MatrixUtils.transformRect(toGlobal, frame.localBounds),
          config: box.config,
          clip: chain.clip,
          opacity: chain.opacity,
          content: MatrixUtils.transformRect(toGlobal, Offset.zero & box.size),
        ),
      );
    }
    final plan = planGlassLayer(inputs);
    _layer.debugLastPlan = plan;

    // Content of groups that draw no glass (or whose glass is clipped
    // away) composites with the first stratum, in paint order.
    final strata = <(List<LayerPass>, List<_Client>)>[
      for (final s in plan)
        (s.passes, [for (final id in s.groups) clients[id]!]),
    ];
    final planned = {for (final s in plan) ...s.groups};
    final rest = [
      ...contentOnly,
      for (final c in clients.values)
        if (!planned.contains(c.box) && !contentOnly.contains(c)) c,
    ];
    if (rest.isNotEmpty) {
      if (strata.isEmpty) strata.add((const [], []));
      final first = [...strata.first.$2, ...rest]
        ..sort((a, b) => _compare(a.chain.order, b.chain.order));
      strata[0] = (strata.first.$1, first);
    }

    final program = GlassProgram.instance.program.value;
    final canDraw = program != null && ui.ImageFilter.isShaderFilterSupported;
    var passIndex = 0;
    for (var i = 0; i < strata.length; i++) {
      if (_keys.length <= i) _keys.add(BackdropKey());
      final (passes, contents) = strata[i];
      if (canDraw) {
        for (final p in passes) {
          if (_shaders.length <= passIndex) {
            _shaders.add(reusedFragmentShader());
          }
          final shader = _shaders[passIndex++].of(program);
          _paintPass(context, offset, fromGlobal, shader, p, _keys[i]);
        }
      }
      for (final c in contents) {
        _paintContent(context, offset, fromGlobal, c);
      }
    }
    // Free the shaders of passes no longer drawn.
    while (_shaders.length > passIndex) {
      _shaders.removeLast().clear();
    }
  }

  static int _compare(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      final c = a[i].compareTo(b[i]);
      if (c != 0) return c;
    }
    return a.length.compareTo(b.length);
  }

  void _paintPass(
    PaintingContext context,
    Offset offset,
    Matrix4 fromGlobal,
    ui.FragmentShader shader,
    LayerPass pass,
    BackdropKey key,
  ) {
    final floats = packGlassUniforms(pass.uniforms);
    for (var i = 0; i < floats.length; i++) {
      shader.setFloat(kFirstUserFloat + i, floats[i]);
    }
    final shaderFilter = ui.ImageFilter.shader(shader);
    final sigma = pass.blurSigma;
    final backdrop = BackdropFilterLayer(
      filter: sigma > 0
          ? ui.ImageFilter.compose(
              outer: shaderFilter,
              inner: ui.ImageFilter.blur(
                sigmaX: sigma * pass.blurAspect,
                sigmaY: sigma / pass.blurAspect,
                tileMode: TileMode.clamp,
              ),
            )
          : shaderFilter,
    )..backdropKey = key;
    context.pushClipRect(
      true,
      offset,
      MatrixUtils.transformRect(fromGlobal, pass.bounds),
      (ctx, o) => ctx.pushLayer(backdrop, (_, _) {}, o),
    );
  }

  void _paintContent(
    PaintingContext context,
    Offset offset,
    Matrix4 fromGlobal,
    _Client c,
  ) {
    final child = c.box.child!;
    final transform = fromGlobal.multiplied(c.toGlobal);
    void content(PaintingContext ctx, Offset o) => ctx.pushTransform(
      true,
      o,
      transform,
      (ctx2, o2) => ctx2.paintChild(child, o2),
    );
    void faded(PaintingContext ctx, Offset o) {
      final a = c.chain.opacity;
      if (a >= 1) return content(ctx, o);
      ctx.pushOpacity(o, (a * 255).round(), content);
    }

    final clip = c.chain.clip;
    if (clip == null) return faded(context, offset);
    context.pushClipRect(
      true,
      offset,
      MatrixUtils.transformRect(fromGlobal, clip),
      faded,
    );
  }
}
