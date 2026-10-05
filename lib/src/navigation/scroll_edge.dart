import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

/// iOS 26's scroll edge effect: content under the bar is blurred and the
/// page background fades out below the top edge, shown while content is
/// under the bar.
class GlassScrollEdge extends StatelessWidget {
  /// Creates the edge.
  const GlassScrollEdge({
    super.key,
    required this.visible,
    required this.height,
    this.blurred = true,
  });

  /// Whether content is under the bar.
  final bool visible;

  /// How far down the fade reaches.
  final double height;

  /// Whether content under the bar is blurred as well as faded. iOS blurs
  /// once a large title has collapsed into the bar.
  final bool blurred;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(
      CupertinoTheme.of(context).scaffoldBackgroundColor,
      context,
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
              // Blur under the bar itself; the fade below hides its edge.
              if (blurred)
                Align(
                  alignment: Alignment.topCenter,
                  child: ClipRect(
                    child: SizedBox(
                      height: height * 0.8,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
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
