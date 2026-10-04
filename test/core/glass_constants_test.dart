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

  test(
    'standard v4: Task 17b fit on lens v3 with size-dependent frost/fill',
    () {
      const c = GlassConstants.standard;
      // Fitted on the NumPy model against SwiftUI (build/fidelity/fit17b),
      // device-verified: 41/75 scenes, median SSIM 0.981, median ΔE 1.50.
      expect(c.regular.blurSigma, 5.9236);
      expect(c.regular.blurSizeRef, 59.9762);
      expect(c.regular.fillOpacity, 0.6804);
      expect(c.regular.fillSizeRef, 43.9952);
      expect(c.regular.fillSizeDrop, 0.1268);
      expect(c.regular.tintStrength, 1.0219);
      expect(c.regularDark.blurSigma, 11.4482);
      expect(c.regularDark.fillSizeDrop, 0.799);
      expect(c.regularDark.fillColor, const Color(0xFF191818));
      expect(c.clear.blurSigma, 1.3993);
      expect(c.clear.blurSizeRef, 0);
      expect(c.clear.fillSizeRef, 0);
      expect(c.clearDark.lensSizeRef, 28.86);
      expect(c.cornerExponent, 2.0);
      expect(c.mergeFactor, 0.8);
      // The lens stays near the Task 15c measurement in every set.
      for (final v in [c.regular, c.regularDark, c.clear, c.clearDark]) {
        expect(v.lensStrength * v.lensBand, closeTo(-47, 3));
        expect(v.lensDecay, closeTo(6.4, 0.6));
      }
    },
  );

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

  test('blurSizeRef reads, overrides, round-trips and compares', () {
    final c = GlassConstants.fromJson({
      'clear': {'blurSizeRef': 25.5},
    });
    expect(c.clear.blurSizeRef, 25.5);
    expect(c.clear.blurSigma, GlassConstants.standard.clear.blurSigma);
    expect(c.regular, GlassConstants.standard.regular);
    expect(c.clear.toJson()['blurSizeRef'], 25.5);
    expect(GlassConstants.fromJson(c.toJson()), c);
    expect(c == GlassConstants.standard, isFalse);
    expect(c.clear.hashCode == GlassConstants.standard.clear.hashCode, isFalse);
  });

  test('fillSizeRef and fillSizeDrop read, override, round-trip, compare', () {
    final c = GlassConstants.fromJson({
      'regularDark': {'fillSizeRef': 60.0, 'fillSizeDrop': 0.25},
    });
    expect(c.regularDark.fillSizeRef, 60);
    expect(c.regularDark.fillSizeDrop, 0.25);
    expect(
      c.regularDark.fillOpacity,
      GlassConstants.standard.regularDark.fillOpacity,
    );
    expect(c.regularDark.toJson()['fillSizeRef'], 60);
    expect(c.regularDark.toJson()['fillSizeDrop'], 0.25);
    expect(GlassConstants.fromJson(c.toJson()), c);
    expect(c == GlassConstants.standard, isFalse);
  });

  test('frost v2 keys default to 0, read, round-trip and compare', () {
    const plain = GlassVariantConstants(
      blurSigma: 1,
      lensBand: 1,
      lensStrength: 1,
      lensDecay: 1,
      lensSizeRef: 0,
      dispersion: 0,
      rimWidth: 1,
      rimIntensity: 0,
      fillColor: Color(0xFFFFFFFF),
      fillOpacity: 0,
      saturation: 1,
      dim: 0,
      shadowRadius: 0,
      shadowOpacity: 0,
      tintStrength: 0,
    );
    expect(plain.frostWideSigma, 0);
    expect(plain.frostWideMixEdge, 0);
    expect(plain.frostWideMixCentre, 0);
    expect(plain.frostWideSizeRef, 0);
    expect(plain.frostWideSizeDrop, 0);
    final c = GlassConstants.fromJson({
      'clearDark': {
        'frostWideSigma': 4.5,
        'frostWideMixEdge': 0.2,
        'frostWideMixCentre': 0.9,
        'frostWideSizeRef': 70.0,
        'frostWideSizeDrop': 1.5,
      },
    });
    expect(c.clearDark.frostWideSigma, 4.5);
    expect(c.clearDark.frostWideMixEdge, 0.2);
    expect(c.clearDark.frostWideMixCentre, 0.9);
    expect(c.clearDark.frostWideSizeRef, 70);
    expect(c.clearDark.frostWideSizeDrop, 1.5);
    expect(c.clearDark.blurSigma, GlassConstants.standard.clearDark.blurSigma);
    expect(c.clearDark.toJson()['frostWideMixCentre'], 0.9);
    expect(GlassConstants.fromJson(c.toJson()), c);
    expect(c == GlassConstants.standard, isFalse);
    expect(
      c.clearDark.hashCode == GlassConstants.standard.clearDark.hashCode,
      isFalse,
    );
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
