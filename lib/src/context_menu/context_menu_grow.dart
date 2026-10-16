import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Scales a context menu by [scale] about its edge nearest the lifted
/// item: its top when the layout put it below the item, its bottom when
/// above (UIKit grows the menu out from the item).
class ContextMenuGrow extends SingleChildRenderObjectWidget {
  /// Scales [child] about the edge facing [itemCenterY] (global).
  const ContextMenuGrow({
    super.key,
    required this.scale,
    required this.itemCenterY,
    super.child,
  });

  /// The menu's scale.
  final double scale;

  /// The lifted item's vertical centre, global coordinates.
  final double itemCenterY;

  @override
  RenderContextMenuGrow createRenderObject(BuildContext context) =>
      RenderContextMenuGrow(scale: scale, itemCenterY: itemCenterY);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderContextMenuGrow renderObject,
  ) => renderObject
    ..scale = scale
    ..itemCenterY = itemCenterY;
}

/// See [ContextMenuGrow].
class RenderContextMenuGrow extends RenderProxyBox {
  /// Creates the render object.
  RenderContextMenuGrow({required double scale, required double itemCenterY})
    : _scale = scale,
      _itemCenterY = itemCenterY;

  double _scale;

  /// The menu's scale.
  double get scale => _scale;
  set scale(double value) {
    if (value == _scale) return;
    _scale = value;
    markNeedsPaint();
  }

  double _itemCenterY;

  /// The lifted item's vertical centre, global coordinates.
  double get itemCenterY => _itemCenterY;
  set itemCenterY(double value) {
    if (value == _itemCenterY) return;
    _itemCenterY = value;
    markNeedsPaint();
  }

  /// Whether the menu sits above the item.
  bool get above => localToGlobal(Offset.zero).dy < _itemCenterY;

  Matrix4 get _transform {
    final a = above
        ? size.bottomCenter(Offset.zero)
        : size.topCenter(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(a.dx, a.dy, 0, 1)
      ..scaleByDouble(_scale, _scale, 1, 1)
      ..translateByDouble(-a.dx, -a.dy, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null || _scale <= 0) return;
    if (_scale == 1) return super.paint(context, offset);
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      super.paint,
      oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      result.addWithPaintTransform(
        transform: _transform,
        position: position,
        hitTest: (result, position) =>
            super.hitTestChildren(result, position: position),
      );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) =>
      transform.multiply(_transform);
}
