import 'dart:convert';
import 'dart:io';

import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/button/glass_button_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json =
      jsonDecode(File('tool/reference/controls.json').readAsStringSync())
          as Map<String, dynamic>;
  final buttons = json['buttons'] as Map<String, dynamic>;

  for (final size in GlassControlSize.values) {
    test('${size.name} matches SwiftUI', () {
      final m = glassButtonMetrics(size);
      final ref = buttons[size.name] as Map<String, dynamic>;
      double r(String k) => (ref[k] as num).toDouble();
      expect(m.height, moreOrLessEquals(r('height'), epsilon: 0.5));
      expect(m.padding, moreOrLessEquals(r('padding'), epsilon: 0.5));
      expect(m.fontSize, moreOrLessEquals(r('font'), epsilon: 0.5));
      expect(m.iconOnlyHeight, moreOrLessEquals(r('icon_only'), epsilon: 0.5));
      expect(
        m.iconOnlyHeight + m.iconOnlyExtraWidth,
        moreOrLessEquals(r('icon_only_width'), epsilon: 0.5),
      );
    });
  }

  test('sizes never shrink', () {
    final h = [
      for (final s in GlassControlSize.values) glassButtonMetrics(s).height,
    ];
    for (var i = 1; i < h.length; i++) {
      expect(h[i], greaterThanOrEqualTo(h[i - 1]));
    }
  });
}
