import 'dart:convert';
import 'dart:io';

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

  test('fillColor is forced opaque so JSON round-trips losslessly', () {
    final c = GlassConstants.fromJson({
      'regular': {'fillColor': 0x80102030},
      'clear': {'fillColor': '#40A0B0C0'},
    });
    expect(c.regular.fillColor, const Color(0xFF102030));
    expect(c.clear.fillColor, const Color(0xFFA0B0C0));
    expect(GlassConstants.fromJson(c.toJson()), c);
  });

  test('standard v3: measured lens (Task 15c) + Task 17 fit', () {
    const c = GlassConstants.standard;
    // Lens v3, decoded from SwiftUI (identical in light and dark).
    for (final v in [c.regular, c.regularDark]) {
      expect(v.lensBand, 18.03);
      expect(v.lensStrength, -2.609);
      expect(v.lensDecay, 6.43);
      expect(v.lensSizeRef, 38.37);
      expect(v.dispersion, 0);
    }
    for (final v in [c.clear, c.clearDark]) {
      expect(v.lensBand, 18.42);
      expect(v.lensStrength, -2.529);
      expect(v.lensDecay, 6.52);
      expect(v.lensSizeRef, 0);
      expect(v.dispersion, 0);
    }
    // The rest comes from the Task 17 fit (build/fidelity/fit/best.json).
    expect(c.regular.blurSigma, 5.1888);
    expect(c.regular.fillColor, const Color(0xFFFEFEFE));
    expect(c.regular.fillOpacity, 0.6336);
    expect(c.regularDark.fillColor, const Color(0xFF1F1A19));
    expect(c.clear.blurSigma, 1.3764);
    expect(c.clearDark.fillColor, const Color(0xFFFDFAFB));
    expect(c.cornerExponent, 2.0);
    expect(c.mergeFactor, 1.0);
  });

  test('lensDecay and lensSizeRef read, override and compare', () {
    final c = GlassConstants.fromJson({
      'regular': {'lensDecay': 4.5, 'lensSizeRef': 20},
    });
    expect(c.regular.lensDecay, 4.5);
    expect(c.regular.lensSizeRef, 20);
    expect(c.regular.lensBand, GlassConstants.standard.regular.lensBand);
    expect(c.regular.toJson()['lensDecay'], 4.5);
    expect(c.regular.toJson()['lensSizeRef'], 20);
    expect(GlassConstants.fromJson(c.toJson()), c);
    expect(c == GlassConstants.standard, isFalse);
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

  test('standard matches tool/fidelity/standard_constants.json', () {
    // The NumPy model fills missing keys from that file, so it must stay the
    // exact JSON form of GlassConstants.standard.
    final file = jsonDecode(
      File('tool/fidelity/standard_constants.json').readAsStringSync(),
    );
    void same(Object? a, Object? b, String path) {
      if (a is Map) {
        expect(b, isA<Map<Object?, Object?>>(), reason: path);
        expect((b! as Map).keys.toSet(), a.keys.toSet(), reason: path);
        for (final k in a.keys) {
          same(a[k], (b as Map)[k], '$path.$k');
        }
      } else if (a is num) {
        expect(b, isA<num>(), reason: path);
        expect((b! as num).toDouble(), a.toDouble(), reason: path);
      } else {
        expect(b, a, reason: path);
      }
    }

    same(GlassConstants.standard.toJson(), file, 'standard');
  });
}
