import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports its child's size after each layout.
class MeasureSize extends SingleChildRenderObjectWidget {
  /// Calls [onSize] with the child's size.
  const MeasureSize({super.key, required this.onSize, super.child});

  /// Called after layout with the child's size.
  final ValueChanged<Size> onSize;

  @override
  RenderMeasureSize createRenderObject(BuildContext context) =>
      RenderMeasureSize(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMeasureSize renderObject,
  ) => renderObject.onSize = onSize;
}

/// The render object of [MeasureSize].
class RenderMeasureSize extends RenderProxyBox {
  /// Reports to [onSize].
  RenderMeasureSize(this.onSize);

  /// Called after layout with the child's size.
  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}
