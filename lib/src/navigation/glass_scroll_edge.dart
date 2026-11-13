import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import '../core/effective_glass_mode.dart';
import '../core/glass_mode_builder.dart';
import 'glass_scroll_edge_style.dart';
import 'nav_bar_metrics.dart';
import 'progressive_blur.dart';

/// Which edge of the screen a [GlassScrollEdge] sits on.
enum GlassScrollEdgePosition {
  /// Under a top bar: the fade runs down from the top.
  top,

  /// Over a bottom bar: the fade runs up from the bottom.
  bottom,
}

/// iOS 26's scroll edge effect: content under the bar is blurred and the
/// page background fades out away from the [edge], shown while content is
/// under the bar.
///
/// The glass bars draw it themselves; place one directly for custom
/// chrome, sized to the bar's height plus its fade:
///
/// ```dart
/// Positioned(
///   left: 0, right: 0, bottom: 0,
///   child: GlassScrollEdge(
///     visible: scrolledUnder,
///     height: 120,
///     edge: GlassScrollEdgePosition.bottom,
///     color: pageColor,
///   ),
/// )
/// ```
class GlassScrollEdge extends StatelessWidget {
  /// Creates the edge.
  const GlassScrollEdge({
    super.key,
    required this.visible,
    required this.height,
    this.blurred = true,
    this.style = GlassScrollEdgeStyle.uniform,
    this.edge = GlassScrollEdgePosition.top,
    this.color,
  });

  /// Whether content is under the bar.
  final bool visible;

  /// How far down the fade reaches.
  final double height;

  /// Whether content under the bar is blurred as well as faded. iOS blurs
  /// once a large title has collapsed into the bar.
  ///
  /// Never on the native path: the page's glass there is UIKit views, which
  /// Flutter cannot blur in place. It either lays a light blur view over
  /// them or moves the blur into an overlay with nothing behind it, and
  /// which it does changes from frame to frame as they scroll, so the
  /// content under the bar flickers between blurred, sharp and dimmed.
  final bool blurred;

  /// How content under the bar is blurred. At the bottom edge
  /// [GlassScrollEdgeStyle.progressive] blurs uniformly.
  final GlassScrollEdgeStyle style;

  /// The edge the effect sits on.
  final GlassScrollEdgePosition edge;

  /// The colour content fades into; defaults to the Cupertino theme's
  /// scaffold background. Set it to the page's colour on a tinted or
  /// custom background.
  final Color? color;

  @override
  Widget build(BuildContext context) => GlassModeBuilder(
    // The page's glass follows the theme's default.
    builder: (context, mode) =>
        _edge(context, blur: blurred && mode != EffectiveGlassMode.native),
  );

  Widget _edge(BuildContext context, {required bool blur}) {
    if (style == GlassScrollEdgeStyle.hidden) return const SizedBox.shrink();
    final hard = style == GlassScrollEdgeStyle.hard;
    final bg = CupertinoDynamicColor.resolve(
      color ?? CupertinoTheme.of(context).scaffoldBackgroundColor,
      context,
    );
    // Blur under the bar itself; the fade below hides its edge.
    final top = edge == GlassScrollEdgePosition.top;
    final uniform = Align(
      alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
      child: ClipRect(
        child: SizedBox(
          height: hard ? height : height * NavBarMetrics.edgeBlurExtent,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: NavBarMetrics.edgeBlurSigma,
              sigmaY: NavBarMetrics.edgeBlurSigma,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (blur)
                style == GlassScrollEdgeStyle.progressive && top
                    // Graduated over the whole edge: the fade below adds
                    // to it rather than hiding a hard lower edge.
                    ? ProgressiveBlur(
                        maxSigma: NavBarMetrics.edgeProgressiveSigma,
                        falloff: NavBarMetrics.edgeProgressiveFalloff,
                        fallback: uniform,
                      )
                    : uniform,
              DecoratedBox(
                decoration: hard
                    // A flat tint with a crisp lower edge.
                    ? BoxDecoration(
                        color: bg.withValues(
                          alpha: NavBarMetrics.edgeHardTintAlpha,
                        ),
                      )
                    : BoxDecoration(
                        gradient: LinearGradient(
                          begin: top
                              ? Alignment.topCenter
                              : Alignment.bottomCenter,
                          end: top
                              ? Alignment.bottomCenter
                              : Alignment.topCenter,
                          colors: [
                            bg,
                            bg.withValues(alpha: 0.85),
                            bg.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.6, 1],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
