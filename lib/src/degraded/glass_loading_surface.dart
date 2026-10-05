import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';
import '../core/glass_shape.dart';
import '../core/shape_border.dart';
import 'degraded_glass.dart';

/// Shader-less glass shown while the shader program loads.
///
/// It paints what `DegradedGlass` paints (blur, fill and rim, or the opaque
/// fill under Reduce Transparency), but as one render object, so turning it
/// off or switching to the opaque fill keeps the child mounted. Disabled,
/// it paints only the child and adds no layer and no compositing.
class GlassLoadingSurface extends StatelessWidget {
  /// Creates the surface.
  const GlassLoadingSurface({
    super.key,
    required this.enabled,
    required this.glass,
    required this.shape,
    required this.constants,
    this.opaqueColor,
    required this.child,
  });

  /// Whether to draw; false once the shader has loaded.
  final bool enabled;

  /// Glass description.
  final Glass glass;

  /// Shape.
  final GlassShape shape;

  /// Rendering constants.
  final GlassConstants constants;

  /// Non-null when Reduce Transparency forces a solid surface.
  final Color? opaqueColor;

  /// Content.
  final Widget child;

  @override
  Widget build(BuildContext context) => _LoadingSurface(
    enabled: enabled && glass.variant != GlassVariant.identity,
    border: sizeIndependentBorder(shape),
    look: DegradedLook.of(
      glass,
      constants,
      MediaQuery.platformBrightnessOf(context),
    ),
    opaqueColor: opaqueColor,
    textDirection: Directionality.maybeOf(context),
    child: child,
  );
}

class _LoadingSurface extends SingleChildRenderObjectWidget {
  const _LoadingSurface({
    required this.enabled,
    required this.border,
    required this.look,
    required this.opaqueColor,
    required this.textDirection,
    super.child,
  });

  final bool enabled;
  final OutlinedBorder border;
  final DegradedLook look;
  final Color? opaqueColor;
  final TextDirection? textDirection;

  @override
  RenderGlassLoadingSurface createRenderObject(BuildContext context) =>
      RenderGlassLoadingSurface(
        enabled: enabled,
        border: border,
        look: look,
        opaqueColor: opaqueColor,
        textDirection: textDirection,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassLoadingSurface renderObject,
  ) {
    renderObject
      ..enabled = enabled
      ..border = border
      ..look = look
      ..opaqueColor = opaqueColor
      ..textDirection = textDirection;
  }
}

/// See [GlassLoadingSurface].
class RenderGlassLoadingSurface extends RenderProxyBox {
  /// Creates the render object.
  RenderGlassLoadingSurface({
    required bool enabled,
    required OutlinedBorder border,
    required DegradedLook look,
    Color? opaqueColor,
    TextDirection? textDirection,
  }) : _enabled = enabled,
       _border = border,
       _look = look,
       _opaqueColor = opaqueColor,
       _textDirection = textDirection;

  final LayerHandle<ClipPathLayer> _clip = LayerHandle<ClipPathLayer>();
  final LayerHandle<BackdropFilterLayer> _blur =
      LayerHandle<BackdropFilterLayer>();

  /// Whether the surface draws.
  bool get enabled => _enabled;
  bool _enabled;
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// The shape's border.
  OutlinedBorder get border => _border;
  OutlinedBorder _border;
  set border(OutlinedBorder value) {
    if (value == _border) return;
    _border = value;
    markNeedsPaint();
  }

  /// Blur, fill and rim.
  DegradedLook get look => _look;
  DegradedLook _look;
  set look(DegradedLook value) {
    if (value == _look) return;
    _look = value;
    markNeedsPaint();
  }

  /// Reduce Transparency fill; replaces the blur when non-null.
  Color? get opaqueColor => _opaqueColor;
  Color? _opaqueColor;
  set opaqueColor(Color? value) {
    if (value == _opaqueColor) return;
    final blurred = _blurs;
    _opaqueColor = value;
    if (blurred != _blurs) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// For directional borders.
  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
  }

  /// Only the backdrop blur needs a layer; the opaque fill and the
  /// disabled surface paint straight onto the canvas.
  bool get _blurs => _enabled && _opaqueColor == null;

  @override
  bool get alwaysNeedsCompositing => _blurs;

  @override
  void dispose() {
    _clip.layer = null;
    _blur.layer = null;
    super.dispose();
  }

  void _paintSurface(Canvas canvas, Rect rect, Color fill, BorderSide? rim) {
    canvas.drawPath(
      _border.getOuterPath(rect, textDirection: _textDirection),
      Paint()..color = fill,
    );
    if (rim != null) {
      _border
          .copyWith(side: rim)
          .paint(canvas, rect, textDirection: _textDirection);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final opaque = _opaqueColor;
    if (!_enabled) {
      _clip.layer = null;
      _blur.layer = null;
      super.paint(context, offset);
      return;
    }
    final rect = offset & size;
    if (opaque != null) {
      _clip.layer = null;
      _blur.layer = null;
      _paintSurface(context.canvas, rect, opaque, null);
      super.paint(context, offset);
      return;
    }
    final blur = _blur.layer ??= BackdropFilterLayer();
    blur.filter = ui.ImageFilter.blur(
      sigmaX: _look.blurSigma,
      sigmaY: _look.blurSigma,
    );
    _clip.layer = context.pushClipPath(
      needsCompositing,
      offset,
      Offset.zero & size,
      _border.getOuterPath(Offset.zero & size, textDirection: _textDirection),
      (ctx, o) => ctx.pushLayer(blur, (inner, p) {
        _paintSurface(inner.canvas, p & size, _look.fill, _look.rim);
        super.paint(inner, p);
      }, o),
      oldLayer: _clip.layer,
    );
  }
}
