import 'dart:math' as math;

import 'package:adaptive_liquid_glass/src/core/swiftui_spring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dampingFraction 1 is critically damped', () {
    final s = swiftUISpring(response: 0.5, dampingFraction: 1);
    expect(s.mass, 1);
    expect(s.damping * s.damping, closeTo(4 * s.mass * s.stiffness, 1e-6));
  });

  test('stiffness follows the response period', () {
    final s = swiftUISpring(response: 0.5, dampingFraction: 0.7);
    expect(s.stiffness, closeTo(math.pow(2 * math.pi / 0.5, 2), 1e-9));
    expect(s.damping, closeTo(4 * math.pi * 0.7 / 0.5, 1e-9));
  });
}
