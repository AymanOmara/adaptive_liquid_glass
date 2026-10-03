import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presets have no tint and are not interactive', () {
    for (final g in [Glass.regular, Glass.clear, Glass.identity]) {
      expect(g.tintColor, isNull);
      expect(g.isInteractive, isFalse);
    }
    expect(Glass.regular.variant, GlassVariant.regular);
    expect(Glass.clear.variant, GlassVariant.clear);
    expect(Glass.identity.variant, GlassVariant.identity);
  });

  test('tint and interactive chain without mutating the original', () {
    const blue = Color(0xFF0000FF);
    final g = Glass.regular.tint(blue).interactive();
    expect(g.variant, GlassVariant.regular);
    expect(g.tintColor, blue);
    expect(g.isInteractive, isTrue);
    expect(Glass.regular.tintColor, isNull);
    expect(g.interactive(false).isInteractive, isFalse);
    expect(g.tint(null).tintColor, isNull);
  });

  test('value equality', () {
    const red = Color(0xFFFF0000);
    expect(Glass.clear.tint(red), Glass.clear.tint(red));
    expect(Glass.clear.tint(red).hashCode, Glass.clear.tint(red).hashCode);
    expect(Glass.clear, isNot(Glass.regular));
  });
}
