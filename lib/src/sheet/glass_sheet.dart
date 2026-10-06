import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../group/glass_group.dart';
import '../liquid_glass.dart';
import 'sheet_metrics.dart';

/// The surface of an iOS 26 sheet, with a grabber. [showGlassSheet] puts
/// one in a modal route.
///
/// At [expansion] 0 it is SwiftUI's sheet at a partial detent: glass
/// floating in from the screen's edges. Towards 1 it becomes the large
/// detent's sheet: edge to edge, opaque, with the screen's corners at the
/// bottom.
class GlassSheet extends StatelessWidget {
  /// Creates a sheet surface.
  const GlassSheet({
    super.key,
    required this.child,
    this.showGrabber = true,
    this.expansion = 0,
    this.glass,
    this.mode,
  });

  /// The sheet's content.
  final Widget child;

  /// Whether to draw the grabber at the top.
  final bool showGrabber;

  /// 0 floating (a partial detent), 1 edge to edge (the large detent).
  final double expansion;

  /// The glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    final t = expansion.clamp(0.0, 1.0);
    final inset = lerpDouble(SheetMetrics.inset, 0, t)!;
    // The glass keeps one radius: it ends at the large sheet's bottom
    // radius, so the opaque surface (top 42, bottom 62) always covers it.
    final glassRadius = lerpDouble(
      SheetMetrics.cornerRadius,
      SheetMetrics.largeBottomRadius,
      t,
    )!;
    final opaque = (t * 2).clamp(0.0, 1.0);
    final surface = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    );
    final opaqueShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(
          lerpDouble(
            SheetMetrics.cornerRadius,
            SheetMetrics.largeTopRadius,
            t,
          )!,
        ),
        bottom: Radius.circular(glassRadius),
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showGrabber)
          Padding(
            padding: const EdgeInsets.only(top: SheetMetrics.grabberTop),
            child: Center(
              child: Container(
                width: SheetMetrics.grabberWidth,
                height: SheetMetrics.grabberHeight,
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: CupertinoDynamicColor.resolve(
                    CupertinoColors.tertiaryLabel,
                    context,
                  ),
                ),
              ),
            ),
          ),
        Flexible(child: child),
      ],
    );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(inset, 0, inset, inset),
      // Passthrough: a detent's tight height reaches the content; without
      // one the sheet is as tall as its content.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Past halfway the opaque surface covers the glass entirely; the
          // glass leaves the tree then (fading native glass is not
          // possible).
          if (opaque < 1)
            Positioned.fill(
              child: GlassGroup(
                mode: mode,
                child: LiquidGlass(
                  glass: glass,
                  mode: mode,
                  shape: GlassShape.rect(glassRadius),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          if (opaque > 0)
            Positioned.fill(
              child: Opacity(
                opacity: opaque,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: opaqueShape,
                    color: surface,
                  ),
                ),
              ),
            ),
          content,
        ],
      ),
    );
  }
}
