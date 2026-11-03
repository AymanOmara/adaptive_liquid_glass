import 'dart:convert';
import 'dart:io';

import 'package:adaptive_liquid_glass/src/button/system_button_metrics.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-glass fills and disabled ink match two SwiftUI backgrounds', () {
    final reference =
        jsonDecode(
              File('tool/reference/system_buttons.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    Color rgb(List<dynamic> channels) => Color.fromARGB(
      255,
      channels[0] as int,
      channels[1] as int,
      channels[2] as int,
    );
    void matches(Color actual, List<dynamic> expected) {
      final value = actual.toARGB32();
      for (var i = 0; i < 3; i++) {
        expect(
          (((value >> (16 - 8 * i)) & 255) - (expected[i] as int)).abs(),
          lessThanOrEqualTo(1),
        );
      }
    }

    for (final sample in reference['samples'] as List<dynamic>) {
      final dark = sample['mode'] == 'dark';
      final background = rgb(sample['background'] as List<dynamic>);
      final fill = dark
          ? GlassColors.borderedButtonFill.darkColor
          : GlassColors.borderedButtonFill.color;
      final label = dark
          ? GlassColors.buttonDisabledLabel.darkColor
          : GlassColors.buttonDisabledLabel.color;
      final neutral = Color.alphaBlend(fill, background);
      final rows = sample['rows'] as List<dynamic>;
      matches(neutral, rows[0][0]['fill'] as List<dynamic>);
      matches(neutral, rows[2][0]['fill'] as List<dynamic>);
      final tinted = Color.alphaBlend(
        const Color(0xFF0080FF).withValues(
          alpha: dark
              ? SystemButtonMetrics.tintedFillOpacityDark
              : SystemButtonMetrics.tintedFillOpacityLight,
        ),
        background,
      );
      matches(tinted, rows[1][0]['fill'] as List<dynamic>);
      for (final row in rows) {
        matches(neutral, row[1]['fill'] as List<dynamic>);
        matches(
          Color.alphaBlend(label, neutral),
          row[1]['label'] as List<dynamic>,
        );
      }
    }
  });
}
