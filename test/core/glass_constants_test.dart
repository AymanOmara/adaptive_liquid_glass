import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JSON round-trips', () {
    const c = GlassConstants.standard;
    expect(GlassConstants.fromJson(c.toJson()), c);
  });

  test('partial JSON overrides only given keys', () {
    final c = GlassConstants.fromJson({
      'regular': {'blurSigma': 9.0},
      'cornerExponent': 5.0,
    });
    expect(c.regular.blurSigma, 9.0);
    expect(c.regular.lensBand, GlassConstants.standard.regular.lensBand);
    expect(c.cornerExponent, 5.0);
    expect(c.clear, GlassConstants.standard.clear);
  });

  test('of() picks the variant and brightness; identity maps to regular', () {
    const c = GlassConstants.standard;
    expect(c.of(GlassVariant.clear), c.clear);
    expect(c.of(GlassVariant.identity), c.regular);
    expect(c.of(GlassVariant.regular, Brightness.dark), c.regularDark);
    expect(c.of(GlassVariant.clear, Brightness.dark), c.clearDark);
  });
}
