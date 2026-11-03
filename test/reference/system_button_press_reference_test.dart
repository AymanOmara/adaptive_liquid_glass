import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:adaptive_liquid_glass/src/button/glass_button_style.dart';
import 'package:adaptive_liquid_glass/src/button/system_button_metrics.dart';
import 'package:adaptive_liquid_glass/src/button/system_button_press.dart';
import 'package:adaptive_liquid_glass/src/core/glass_colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reference =
      jsonDecode(
            File('tool/reference/system_button_press.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  Color rgb(List<dynamic> values) =>
      Color.fromARGB(255, values[0] as int, values[1] as int, values[2] as int);
  void matches(Color actual, List<dynamic> expected) {
    final value = actual.toARGB32();
    for (var i = 0; i < 3; i++) {
      expect(
        (((value >> (16 - i * 8)) & 255) - (expected[i] as int)).abs(),
        lessThanOrEqualTo(1),
      );
    }
  }

  for (final sample in reference['samples'] as List<dynamic>) {
    final name = sample['style'] as String;
    final dark = sample['mode'] == 'dark';
    test('$name ${sample['mode']}: held fill and label match SwiftUI', () {
      final prominent = name.contains('prominent');
      final borderless = name.contains('borderless');
      final tinted = name == 'tinted';
      final style = prominent
          ? GlassButtonStyle.borderedProminent
          : borderless
          ? GlassButtonStyle.borderless
          : name == 'plain'
          ? GlassButtonStyle.plain
          : GlassButtonStyle.bordered;
      final background = dark
          ? const Color(0xFF000000)
          : const Color(0xFFFFFFFF);
      final idle = sample['idle'] as List<dynamic>;
      final label = rgb(idle[1] as List<dynamic>);
      final Color? fill = prominent
          ? rgb(idle[0] as List<dynamic>)
          : style != GlassButtonStyle.bordered
          ? null
          : tinted
          ? label.withValues(alpha: dark ? 0.25 : 0.18)
          : dark
          ? GlassColors.borderedButtonFill.darkColor
          : GlassColors.borderedButtonFill.color;
      final highlight = SystemButtonPress.fill(
        fill,
        style,
        dark: dark,
        tinted: tinted,
      );
      final underLabel = highlight == null
          ? background
          : Color.alphaBlend(highlight, background);
      final ink = Color.lerp(
        label,
        const Color(0xFFFFFFFF),
        SystemButtonPress.labelWhiteMix(style, dark: dark),
      )!;
      final output = Color.alphaBlend(
        ink.withValues(
          alpha: SystemButtonPress.labelOpacity(style, dark: dark),
        ),
        underLabel,
      );
      final held = sample['held'] as List<dynamic>;
      matches(underLabel, held[0] as List<dynamic>);
      matches(output, held[1] as List<dynamic>);
    });
  }

  test('release curve follows the lossless plain-label recording', () {
    final samples = reference['plain_light_release'] as List<dynamic>;
    var squaredError = 0.0;
    for (var i = 0; i < samples.length; i++) {
      final time = i / (reference['fps'] as int);
      final fraction =
          (time * 1000000 / SystemButtonMetrics.pressOut.inMicroseconds).clamp(
            0.0,
            1.0,
          );
      final expected = (samples[i] as num).toDouble();
      final actual =
          64 * (1 - SystemButtonMetrics.releaseCurve.transform(fraction));
      squaredError += math.pow(actual - expected, 2);
    }
    expect(math.sqrt(squaredError / samples.length), lessThan(1));
    expect(SystemButtonMetrics.pressIn, Duration.zero);
  });
}
