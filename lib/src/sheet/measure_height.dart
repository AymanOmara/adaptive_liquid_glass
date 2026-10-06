import 'package:flutter/widgets.dart';

import 'render_measure_height.dart';

/// Reports its child's height after each layout.
class MeasureHeight extends SingleChildRenderObjectWidget {
  /// Calls [onHeight] with the child's height.
  const MeasureHeight({super.key, required this.onHeight, super.child});

  /// Called after layout with the child's height.
  final ValueChanged<double> onHeight;

  @override
  RenderMeasureHeight createRenderObject(BuildContext context) =>
      RenderMeasureHeight(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderMeasureHeight renderObject,
  ) => renderObject.onHeight = onHeight;
}
