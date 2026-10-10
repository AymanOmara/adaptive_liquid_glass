import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_colors.dart';
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
    this.cornerRadius,
    this.grabberSize,
    this.expansion = 0,
    this.glass,
    this.mode,
  });

  /// The sheet's content.
  final Widget child;

  /// Whether to draw the grabber at the top.
  final bool showGrabber;

  /// The floating sheet's corner radius. Defaults to iOS 26's (38). The
  /// large detent keeps iOS's own corners.
  final double? cornerRadius;

  /// The grabber's size. Defaults to iOS 26's (34.67 x 5).
  final Size? grabberSize;

  /// 0 floating (a partial detent), 1 edge to edge (the large detent).
  final double expansion;

  /// The glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    final t = expansion.clamp(0.0, 1.0);
    final radius = cornerRadius ?? SheetMetrics.cornerRadius;
    final inset = lerpDouble(SheetMetrics.inset, 0, t)!;
    // The glass keeps one radius: it ends at the large sheet's bottom
    // radius, so the opaque surface (top 42, bottom 62) always covers it.
    final glassRadius = lerpDouble(radius, SheetMetrics.largeBottomRadius, t)!;
    final opaque = (t * 2).clamp(0.0, 1.0);
    final opaqueShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(
          lerpDouble(radius, SheetMetrics.largeTopRadius, t)!,
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
                width: grabberSize?.width ?? SheetMetrics.grabberWidth,
                height: grabberSize?.height ?? SheetMetrics.grabberHeight,
                decoration: ShapeDecoration(
                  shape: const StadiumBorder(),
                  color: CupertinoDynamicColor.resolve(
                    GlassColors.tertiaryLabel,
                    context,
                  ),
                ),
              ),
            ),
          ),
        Flexible(child: child),
      ],
    );
    // A sheet is elevated content: iOS resolves system colours (its
    // surface, its content's backgrounds) to their elevated variants, e.g.
    // #1C1C1E instead of black in dark mode.
    return CupertinoUserInterfaceLevel(
      data: CupertinoUserInterfaceLevelData.elevated,
      child: Builder(
        builder: (context) => _surface(
          context,
          t,
          inset,
          glassRadius,
          opaque,
          opaqueShape,
          content,
        ),
      ),
    );
  }

  Widget _surface(
    BuildContext context,
    double t,
    double inset,
    double glassRadius,
    double opaque,
    ShapeBorder opaqueShape,
    Widget content,
  ) {
    final surface = CupertinoDynamicColor.resolve(
      GlassColors.sheetBackground,
      context,
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
