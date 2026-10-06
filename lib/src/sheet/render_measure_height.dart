import 'package:flutter/rendering.dart';

/// The render object of `MeasureHeight`.
class RenderMeasureHeight extends RenderProxyBox {
  /// Reports to [onHeight].
  RenderMeasureHeight(this.onHeight);

  /// Called after layout with the child's height.
  ValueChanged<double> onHeight;

  @override
  void performLayout() {
    super.performLayout();
    onHeight(size.height);
  }
}
