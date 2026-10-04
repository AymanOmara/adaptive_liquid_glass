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

  test('fillColor reads #RRGGBB and int ARGB; toJson writes #RRGGBB', () {
    final c = GlassConstants.fromJson({
      'regular': {'fillColor': '#1C1C1E', 'fillOpacity': 0.4},
      'clear': {'fillColor': 0xFF102030},
      'mergeFactor': 1.5,
    });
    expect(c.regular.fillColor, const Color(0xFF1C1C1E));
    expect(c.regular.fillOpacity, 0.4);
    expect(c.regular.saturation, GlassConstants.standard.regular.saturation);
    expect(c.clear.fillColor, const Color(0xFF102030));
    expect(c.mergeFactor, 1.5);
    expect(c.regularDark, GlassConstants.standard.regularDark);
    expect(c.regular.toJson()['fillColor'], '#1C1C1E');
    expect(c.toJson()['mergeFactor'], 1.5);
  });

  test('standard v2 starting values', () {
    const c = GlassConstants.standard;
    expect(c.regular.fillColor, const Color(0xFFFFFFFF));
    expect(c.regular.fillOpacity, 0.30);
    expect(c.regular.saturation, 0.75);
    expect(c.regular.dim, 0);
    expect(c.regular.blurSigma, 12);
    expect(c.clear.fillOpacity, 0.05);
    expect(c.clear.saturation, 1.0);
    expect(c.clear.dim, 0.2);
    expect(c.clear.blurSigma, 2);
    expect(c.regularDark.fillColor, const Color(0xFF1C1C1E));
    expect(c.regularDark.fillOpacity, 0.55);
    expect(c.regularDark.dim, 0);
    expect(c.regularDark.blurSigma, 12);
    expect(c.clearDark.fillColor, const Color(0xFF000000));
    expect(c.clearDark.fillOpacity, 0.20);
    expect(c.clearDark.dim, 0.3);
    expect(c.clearDark.blurSigma, 2);
    expect(c.mergeFactor, 1.0);
  });

  test('different fill colours are not equal', () {
    final a = GlassConstants.fromJson({
      'regular': {'fillColor': '#000000'},
    });
    expect(a == GlassConstants.standard, isFalse);
    expect(
      a.regular.hashCode == GlassConstants.standard.regular.hashCode,
      isFalse,
    );
  });

  test('of() picks the variant and brightness; identity maps to regular', () {
    const c = GlassConstants.standard;
    expect(c.of(GlassVariant.clear), c.clear);
    expect(c.of(GlassVariant.identity), c.regular);
    expect(c.of(GlassVariant.regular, Brightness.dark), c.regularDark);
    expect(c.of(GlassVariant.clear, Brightness.dark), c.clearDark);
  });
}
