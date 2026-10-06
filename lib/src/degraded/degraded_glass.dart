import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/glass.dart';
import '../core/glass_constants.dart';
import '../core/glass_shape.dart';
import '../core/glass_variant.dart';
import '../core/shape_border.dart';
import '../group/glass_group_scope.dart';
import 'degraded_look.dart';

/// Glass without shader support: blur, tint and a rim; no lensing or merging.
///
/// Under Reduce Transparency it is a solid fill instead. The two trees
/// differ, so the child sits under a [GlobalKey]: toggling the setting
/// reparents it rather than remounting it.
class DegradedGlass extends StatefulWidget {
  /// Creates a degraded glass surface.
  const DegradedGlass({
    super.key,
    required this.glass,
    required this.shape,
    required this.constants,
    this.opaqueColor,
    required this.child,
  });

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
  State<DegradedGlass> createState() => _DegradedGlassState();
}

class _DegradedGlassState extends State<DegradedGlass> {
  final GlobalKey _content = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final glass = widget.glass;
    final child = KeyedSubtree(key: _content, child: widget.child);
    if (glass.variant == GlassVariant.identity) return child;
    final shape = widget.shape;
    final constants = widget.constants;
    final opaqueColor = widget.opaqueColor;
    final border = sizeIndependentBorder(shape);

    final opaque = opaqueColor;
    if (opaque != null) {
      return DecoratedBox(
        decoration: ShapeDecoration(color: opaque, shape: border),
        child: child,
      );
    }

    final look = DegradedLook.of(
      glass,
      constants,
      // The group's resolved brightness; outside a group, the ambient
      // MediaQuery. See GlassGroupScope.brightnessOf.
      GlassGroupScope.brightnessOf(context),
    );
    return ClipPath(
      clipper: ShapeBorderClipper(shape: border),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: look.blurSigma,
          sigmaY: look.blurSigma,
        ),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: look.fill,
            shape: border.copyWith(side: look.rim),
          ),
          child: child,
        ),
      ),
    );
  }
}
