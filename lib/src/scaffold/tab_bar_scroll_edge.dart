import 'package:flutter/widgets.dart';

import 'scaffold_metrics.dart';

/// iOS 26's scroll edge under a tab bar: scrolling content fades into the
/// page colour towards the bottom of the screen (SwiftUI `TabView` over a
/// `ScrollView`, iOS 26.4, white page: text ink 0 at 115 pt above the
/// bottom edge, 11 at 99, 27 at 88, 59 at 42, 122 at 32, 153 at 25).
class TabBarScrollEdge extends StatelessWidget {
  /// A fade of [color] at the bottom of its box.
  const TabBarScrollEdge({super.key, required this.color});

  /// The page's background colour.
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      height: ScaffoldMetrics.tabBarEdgeHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              for (final a in ScaffoldMetrics.tabBarEdgeAlphas)
                color.withValues(alpha: a),
            ],
            stops: ScaffoldMetrics.tabBarEdgeStops,
          ),
        ),
      ),
    ),
  );
}
