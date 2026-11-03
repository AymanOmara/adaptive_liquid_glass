import 'dart:convert';
import 'dart:io';

import 'package:adaptive_liquid_glass/src/core/glass_constants.dart';
import 'package:adaptive_liquid_glass/src/interaction/glass_press_controller.dart';
import 'package:adaptive_liquid_glass/src/native/native_glass_layer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reference =
      jsonDecode(File('tool/reference/native_press.json').readAsStringSync())
          as Map<String, dynamic>;
  final coefficients = reference['coefficients'] as Map<String, dynamic>;
  final chroma = reference['chroma_gain'] as Map<String, dynamic>;

  test('native press light matches the measured fit', () {
    final actual = {
      'lightLift': NativePressLight.lightLift,
      'lightGlow': NativePressLight.lightGlow,
      'darkLift': NativePressLight.darkLift,
      'darkGlow': NativePressLight.darkGlow,
      'clearLightLift': NativePressLight.clearLightLift,
      'clearLightGlow': NativePressLight.clearLightGlow,
      'clearDarkLift': NativePressLight.clearDarkLift,
      'clearDarkGlow': NativePressLight.clearDarkGlow,
      'sigma': NativePressLight.sigma,
      'lightSaturation': NativePressLight.lightSaturation,
      'darkSaturation': NativePressLight.darkSaturation,
      'clearSaturation': NativePressLight.clearSaturation,
    };
    for (final entry in actual.entries) {
      expect(
        entry.value,
        closeTo((coefficients[entry.key] as num).toDouble(), 1e-9),
        reason: entry.key,
      );
    }
  });

  test('pressed saturation covers the chroma SwiftUI adds', () {
    double gain(String key) =>
        ((chroma[key] as Map)['swiftui'] as num).toDouble() /
        ((chroma[key] as Map)['native_before'] as num).toDouble();
    // The white lift dilutes the colours, so the saturation asked is about
    // the missing gain or a little above it.
    for (final (saturation, keys) in [
      (NativePressLight.lightSaturation, ['regular_light']),
      (NativePressLight.darkSaturation, ['regular_dark']),
      (NativePressLight.clearSaturation, ['clear_light', 'clear_dark']),
    ]) {
      for (final key in keys) {
        expect(
          saturation,
          inInclusiveRange(gain(key) * 0.98, gain(key) * 1.05),
          reason: key,
        );
      }
    }
  });

  test('small-shape press matches the measured fit', () {
    final small = reference['small'] as Map<String, dynamic>;
    double v(String key) => (small[key] as num).toDouble();
    final motion = GlassConstants.standard.motion;
    final actual = {
      'length': motion.pressSmallLength,
      'growth': motion.pressSmallGrowth,
      'release_response': motion.smallReleaseResponse,
      'release_damping': motion.smallReleaseDamping,
      'lightFrost': NativePressLight.lightFrost,
      'lightFrostWhite': NativePressLight.lightFrostWhite,
      'darkFrost': NativePressLight.darkFrost,
      'darkFrostWhite': NativePressLight.darkFrostWhite,
      'clearFrost': NativePressLight.clearFrost,
      'clearFrostWhite': NativePressLight.clearFrostWhite,
    };
    for (final entry in actual.entries) {
      expect(entry.value, closeTo(v(entry.key), 1e-9), reason: entry.key);
    }
    expect(kPressLightHoldSmall.inMilliseconds, v('hold_ms'));
    // The frost and the growth switch at the same bound.
    expect(NativePressLight.frostLength, motion.pressSmallLength);
  });

  final small = (reference['small_scores'] as Map<String, dynamic>)
    ..remove('note');
  for (final entry in small.entries) {
    test('${entry.key}: small press within bounds', () {
      final after = entry.value as Map<String, dynamic>;
      // Light regular shapes within ~2.5/255; the 44 pt dark and clear
      // circles keep a brighter release hold (README limitation).
      final bound = entry.key.contains('dark') || entry.key.contains('clear')
          ? 6.0
          : 3.0;
      expect(after['press_mae'] as num, lessThan(bound));
      expect(after['held_mae'] as num, lessThan(2.0));
      expect(after['bbox_rms_pt'] as num, lessThan(1.0));
    });
  }

  final scores = (reference['scores'] as Map<String, dynamic>)..remove('note');
  for (final entry in scores.entries) {
    test('${entry.key}: measured press error fell', () {
      final before = entry.value['before'] as Map<String, dynamic>;
      final after = entry.value['after'] as Map<String, dynamic>;
      for (final metric in ['press_mae', 'held_mae']) {
        expect(
          (after[metric] as num) * 1.5,
          lessThan(before[metric] as num),
          reason: metric,
        );
      }
      // Growth and stretch within a point of SwiftUI's.
      expect(after['bbox_rms_pt'] as num, lessThan(1.0));
    });
  }
}
