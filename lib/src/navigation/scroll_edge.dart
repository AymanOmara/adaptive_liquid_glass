import 'package:flutter/cupertino.dart';

/// iOS 26's scroll edge effect: the page background fading out below the
/// top edge, shown while content is under the bar.
class GlassScrollEdge extends StatelessWidget {
  /// Creates the edge.
  const GlassScrollEdge({
    super.key,
    required this.visible,
    required this.height,
  });

  /// Whether content is under the bar.
  final bool visible;

  /// How far down the fade reaches.
  final double height;

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
          child: DecoratedBox(
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
        ),
      ),
    );
  }
}
