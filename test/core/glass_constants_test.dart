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
      'cornerZone': 1.4,
    });
    expect(c.regular.blurSigma, 9.0);
    expect(c.regular.lensBand, GlassConstants.standard.regular.lensBand);
    expect(c.cornerExponent, 5.0);
    expect(c.cornerZone, 1.4);
    expect(c.mergeFactor, GlassConstants.standard.mergeFactor);
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

  test('standard v7: g13 colour refit (small-shape tone curve)', () {
    const c = GlassConstants.standard;
    // Task g13 (build/g13 fits L2/D1, margin search cd/pt): regular and
    // regularDark get fitted tone LUTs plus a small-shape tone curve
    // (smallToneKnots, full weight at half shorter side <= 32 pt, off
    // above 34 pt), and a fill/saturation/tint refit; fillSizeDrop goes
    // to 0 (the small-shape response moved into the small tone LUT).
    expect(c.regular.blurSigma, 5.9236);
    expect(c.regular.toneKnots[4], 0.4853);
    expect(c.regular.toneKnots[8], 0.9919);
    expect(c.regular.smallToneKnots[4], 0.5);
    expect(c.regular.smallToneKnots[8], 0.962);
    expect(c.regular.smallSizeLo, 32);
    expect(c.regular.smallSizeHi, 34);
    expect(c.regular.fillOpacity, 0.6839);
    expect(c.regular.fillSizeRef, 43.9952);
    expect(c.regular.fillSizeDrop, 0);
    expect(c.regular.saturation, 1.7401);
    expect(c.regular.tintStrength, 1.024);
    expect(c.regularDark.blurSigma, 8.2468);
    expect(c.regularDark.toneKnots[1], 0.1917);
    expect(c.regularDark.toneKnots[5], 0.6408);
    expect(c.regularDark.smallToneKnots[4], 0.8295);
    expect(c.regularDark.smallSizeLo, 32);
    expect(c.regularDark.smallSizeHi, 34);
    expect(c.regularDark.toneLift, 0.7708);
    expect(c.regularDark.blurAspectPower, 0.28);
    expect(c.regularDark.rimIntensity, 0.3293);
    expect(c.regularDark.fillColor, const Color(0xFF191818));
    expect(c.regularDark.fillOpacity, 0.6672);
    expect(c.regularDark.fillSizeDrop, 0);
    expect(c.regularDark.saturation, 1.967);
    expect(c.regularDark.tintStrength, 1.0054);
    // Fidelity group 4: clear-lens refit with the post-lens Jacobian clamp.
    expect(c.clear.postBlurShare, 0.31);
    expect(c.clear.lensStrength, -2.49);
    expect(c.clear.blurSigma, 1.28);
    expect(c.clear.postJacobianMax, 1.15);
    expect(c.clearDark.postJacobianMax, 1.15);
    expect(c.regular.postJacobianMax, 4);
    expect(c.regularDark.postJacobianMax, 4);
    expect(c.clear.blurSizeRef, 0);
    expect(c.clear.fillSizeRef, 0);
    expect(c.clearDark.lensSizeRef, 28.7);
    expect(c.cornerExponent, 2.0);
    // Task A1: continuous corners on the outline (zone 1.2 x radius).
    expect(c.cornerZone, 1.2);
    expect(c.mergeFactor, 0.8);
    // The lens stays near the Task 15c measurement in every set.
    for (final v in [c.regular, c.regularDark, c.clear, c.clearDark]) {
      expect(v.lensStrength * v.lensBand, closeTo(-47, 3));
      expect(v.lensDecay, closeTo(6.4, 0.6));
    }
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
    // exact JSON form of GlassConstants.standard. The g13 small-shape tone
    // keys ship for regular/regularDark only; clear/clearDark stay off
    // (identity knots, sizes 0), so the file is completed with those
    // defaults here.
    final file =
        jsonDecode(
              File('tool/fidelity/standard_constants.json').readAsStringSync(),
            )
            as Map<String, Object?>;
    for (final k in ['clear', 'clearDark']) {
      final set = file[k]! as Map<String, Object?>;
      set['smallToneKnots'] = GlassVariantConstants.identityToneKnots;
      set['smallSizeLo'] = 0;
      set['smallSizeHi'] = 0;
    }
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

  test('lensVertical round-trips through JSON', () {
    final c = GlassConstants.fromJson({
      'clear': {'lensVertical': 1.0},
    });
    expect(c.clear.lensVertical, 1.0);
    expect(GlassConstants.fromJson(c.toJson()), c);
  });

  test('small-shape tone keys: on for regular sets, off for clear', () {
    // Task g13: regular/regularDark ship the small-shape tone curve (full
    // weight at half shorter side <= 32 pt, off above 34 pt); clear and
    // clearDark keep it off — identity knots and a closed size window.
    expect(
      GlassConstants.standard.regular.smallToneKnots,
      isNot(GlassVariantConstants.identityToneKnots),
    );
    expect(GlassConstants.standard.regular.smallSizeLo, 32);
    expect(GlassConstants.standard.regular.smallSizeHi, 34);
    expect(
      GlassConstants.standard.regularDark.smallToneKnots,
      isNot(GlassVariantConstants.identityToneKnots),
    );
    expect(GlassConstants.standard.regularDark.smallSizeLo, 32);
    expect(GlassConstants.standard.regularDark.smallSizeHi, 34);
    for (final v in [
      GlassConstants.standard.clear,
      GlassConstants.standard.clearDark,
    ]) {
      expect(v.smallToneKnots, GlassVariantConstants.identityToneKnots);
      expect(v.smallSizeLo, 0);
      expect(v.smallSizeHi, 0);
    }
    final c = GlassConstants.fromJson({
      'regular': {
        'smallToneKnots': [0.0, 0.05, 0.12, 0.22, 0.35, 0.5, 0.68, 0.87, 1.0],
        'smallSizeLo': 30.0,
        'smallSizeHi': 34.0,
      },
    });
    expect(c.regular.smallToneKnots[4], 0.35);
    expect(c.regular.smallSizeLo, 30);
    expect(c.regular.smallSizeHi, 34);
    expect(c.regular.toneKnots, GlassConstants.standard.regular.toneKnots);
    expect(c.clear, GlassConstants.standard.clear);
    expect((c.regular.toJson()['smallToneKnots'] as List)[3], 0.22);
    expect(c.regular.toJson()['smallSizeLo'], 30);
    expect(c.regular.toJson()['smallSizeHi'], 34);
    expect(GlassConstants.fromJson(c.toJson()), c);
    expect(c == GlassConstants.standard, isFalse);
    expect(
      c.regular.hashCode == GlassConstants.standard.regular.hashCode,
      isFalse,
    );
    // A malformed knot list falls back to the base knots.
    final bad = GlassConstants.fromJson({
      'clear': {
        'smallToneKnots': [0, 1, 2],
      },
    });
    expect(
      bad.clear.smallToneKnots,
      GlassConstants.standard.clear.smallToneKnots,
    );
  });
}
