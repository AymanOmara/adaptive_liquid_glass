import 'dart:convert';
import 'dart:io';

import 'package:adaptive_liquid_glass/src/navigation/nav_bar_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final nav =
      (jsonDecode(File('tool/reference/controls.json').readAsStringSync())
              as Map<String, dynamic>)['navbar']
          as Map<String, dynamic>;
  double ref(String k) => (nav[k] as num).toDouble();

  test('bar matches SwiftUI', () {
    expect(
      NavBarMetrics.barHeight,
      moreOrLessEquals(ref('bar_height'), epsilon: 0.5),
    );
    expect(
      NavBarMetrics.edgeInset,
      moreOrLessEquals(ref('edge_inset'), epsilon: 0.5),
    );
    expect(
      NavBarMetrics.item.iconOnlyHeight,
      moreOrLessEquals(ref('button'), epsilon: 0.5),
    );
    expect(
      NavBarMetrics.item.iconOnlyHeight + NavBarMetrics.item.iconOnlyExtraWidth,
      moreOrLessEquals(ref('item_width'), epsilon: 0.5),
    );
    expect(
      NavBarMetrics.largeTitleBaselineBelowBar,
      moreOrLessEquals(ref('large_title_baseline_below_bar'), epsilon: 0.5),
    );
    // Ink of "I" starts ~2 pt inside its advance box.
    expect(
      NavBarMetrics.largeTitleInset,
      moreOrLessEquals(ref('large_title_inset') - 2, epsilon: 0.5),
    );
    expect(NavBarMetrics.inlineThreshold, ref('inline_threshold'));
  });
}
