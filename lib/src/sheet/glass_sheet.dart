import 'package:flutter/cupertino.dart';

import '../core/glass.dart';
import '../core/glass_render_mode.dart';
import '../core/glass_shape.dart';
import '../liquid_glass.dart';
import 'sheet_metrics.dart';

/// The surface of an iOS 26 sheet: glass floating in from the screen's
/// edges, with a grabber. [showGlassSheet] puts one in a modal sheet.
class GlassSheet extends StatelessWidget {
  /// Creates a sheet surface.
  const GlassSheet({
    super.key,
    required this.child,
    this.showGrabber = true,
    this.glass,
    this.mode,
  });

  /// The sheet's content.
  final Widget child;

  /// Whether to draw the grabber at the top.
  final bool showGrabber;

  /// The glass. Defaults to the theme's default glass.
  final Glass? glass;

  /// The rendering path; see [GlassRenderMode].
  final GlassRenderMode? mode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        SheetMetrics.inset,
        0,
        SheetMetrics.inset,
        SheetMetrics.inset,
      ),
      child: LiquidGlass(
        glass: glass,
        mode: mode,
        shape: const GlassShape.rect(SheetMetrics.cornerRadius),
        child: Column(
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
        ),
      ),
    );
  }
}
