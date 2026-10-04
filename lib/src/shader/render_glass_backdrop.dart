import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';
import '../core/glass_shape.dart';
import '../group/glass_entry.dart';
import '../group/glass_registry.dart';
import 'glass_program.dart';
import 'glass_uniforms.dart';
import 'texture_space.dart';

/// Per-group drawing parameters.
@immutable
class GlassBackdropConfig {
  /// Creates a config.
  const GlassBackdropConfig({
    required this.spacing,
    required this.lightAngle,
    required this.devicePixelRatio,
    required this.constants,
    required this.brightness,
    required this.highContrast,
    this.opaqueColor,
  });

  /// Light or dark appearance.
  final Brightness brightness;

  /// Group spacing (logical px).
  final double spacing;

  /// Light direction.
  final double lightAngle;

  /// Device pixel ratio.
  final double devicePixelRatio;

  /// Constants.
  final GlassConstants constants;

  /// Increase Contrast.
  final bool highContrast;

  /// Reduce Transparency fill.
  final Color? opaqueColor;

  @override
  bool operator ==(Object other) =>
      other is GlassBackdropConfig &&
      other.spacing == spacing &&
      other.lightAngle == lightAngle &&
      other.devicePixelRatio == devicePixelRatio &&
      other.constants == constants &&
      other.brightness == brightness &&
      other.highContrast == highContrast &&
      other.opaqueColor == opaqueColor;

  @override
  int get hashCode => Object.hash(
    spacing,
    lightAngle,
    devicePixelRatio,
    constants,
    brightness,
    highContrast,
    opaqueColor,
  );
}

/// What the last paint computed; for tests.
@immutable
class GlassBackdropDebugFrame {
  /// Creates a debug frame.
  const GlassBackdropDebugFrame(
    this.uniforms,
    this.localBounds,
    this.filterOriginGlobal,
  );

  /// Uniforms sent to the shader.
  final GlassFrameUniforms uniforms;

  /// Clip rect, local to the render object.
  final Rect localBounds;

  /// Global logical position of the clip origin.
  final Offset filterOriginGlobal;
}

/// Paints the group's glass behind its child.
class GlassBackdrop extends SingleChildRenderObjectWidget {
  /// Creates the backdrop.
  const GlassBackdrop({
    super.key,
    required this.registry,
    required this.config,
    this.backdropKey,
    super.child,
  });

  /// Members to draw.
  final GlassRegistry registry;

  /// Drawing parameters.
  final GlassBackdropConfig config;

  /// Shared backdrop capture key from an enclosing `BackdropGroup`.
  final BackdropKey? backdropKey;

  @override
  RenderGlassBackdrop createRenderObject(BuildContext context) =>
      RenderGlassBackdrop(
        registry: registry,
        config: config,
        backdropKey: backdropKey,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassBackdrop renderObject,
  ) {
    renderObject
      ..registry = registry
      ..config = config
      ..backdropKey = backdropKey;
  }
}

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

  Rect _baseGlobalRect(GlassEntry e, Matrix4 toGlobal) {
    final morph = e.morphRect;
    if (morph != null) return MatrixUtils.transformRect(toGlobal, morph);
    final box = e.box!;
    return MatrixUtils.transformRect(
      box.getTransformTo(null),
      e.shape.resolveRect(box.size),
    );
  }

  double _baseRadius(GlassEntry e, Rect baseGlobal) {
    final c = e.container;
    final shape = e.shape;
    double? concentric;
    if (shape is ConcentricGlassShape && c != null && c.isLaidOut) {
      final cBox = c.box!;
      concentric = concentricRadius(
        container: MatrixUtils.transformRect(
          cBox.getTransformTo(null),
          c.shape.resolveRect(cBox.size),
        ),
        containerRadius: c.shape.resolveRadius(cBox.size),
        child: baseGlobal,
        minimum: shape.minimum,
      );
    }
    return shape.resolveRadius(baseGlobal.size, concentricRadius: concentric);
  }

  GlassBackdropDebugFrame? _buildFrame() {
    final dpr = _config.devicePixelRatio;
    final toGlobal = getTransformTo(null);
    final fromGlobal = Matrix4.tryInvert(toGlobal);
    if (fromGlobal == null) return null;

    final drawn = <(GlassEntry, Rect, double)>[];
    for (final e in _registry.entries) {
      if (!e.isLaidOut || e.glass.variant == GlassVariant.identity) continue;
      final base = _baseGlobalRect(e, toGlobal);
      if (!base.isFinite || base.isEmpty) continue;
      final radius = _baseRadius(e, base) * e.press.radiusScale;
      drawn.add((e, e.press.apply(base), radius));
    }
    if (drawn.isEmpty) return null;

    final union = drawn.map((d) => d.$2).reduce((a, b) => a.expandToInclude(b));
    final c = _config.constants;
    final shadow = [
      c.regular,
      c.clear,
      c.regularDark,
      c.clearDark,
    ].map((v) => v.shadowRadius).reduce(math.max);
    final margin = shadow * 2 + _config.spacing + 2;
    final localBounds = MatrixUtils.transformRect(
      fromGlobal,
      union,
    ).inflate(margin);
    final origin = MatrixUtils.transformPoint(toGlobal, localBounds.topLeft);

    final shapes = mergeUnions([
      for (final (e, rect, radius) in drawn)
        GlassShapeUniform(
          rect: toTextureSpace(
            rect,
            filterOriginGlobal: origin,
            devicePixelRatio: dpr,
          ),
          radius: radius * dpr,
          variant: e.glass.variant,
          tint: e.glass.tintColor,
          unionId: e.unionId,
        ),
    ]);

    Offset? touch;
    var glow = 0.0;
    for (final (e, _, _) in drawn) {
      final p = e.press.touch;
      if (p != null && e.press.glow > glow) {
        glow = e.press.glow;
        touch = pointToTextureSpace(
          MatrixUtils.transformPoint(e.box!.getTransformTo(null), p),
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
        smoothing: 2 * _config.spacing * dpr,
        constants: c,
        brightness: _config.brightness,
        highContrast: _config.highContrast,
        opaqueColor: _config.opaqueColor,
        touch: touch,
        glow: glow,
      ),
      localBounds,
      origin,
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
    backdrop
      ..filter = ui.ImageFilter.shader(shader)
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
