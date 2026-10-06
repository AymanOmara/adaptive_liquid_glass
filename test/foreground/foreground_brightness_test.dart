import 'package:adaptive_liquid_glass/src/foreground/foreground_brightness.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('without a current brightness the middle grey decides', () {
    expect(foregroundBrightnessFor(0.51), Brightness.light);
    expect(foregroundBrightnessFor(0.49), Brightness.dark);
  });

  test('near middle grey the labels keep what they have', () {
    expect(
      foregroundBrightnessFor(0.45, current: Brightness.light),
      Brightness.light,
    );
    expect(
      foregroundBrightnessFor(0.55, current: Brightness.dark),
      Brightness.dark,
    );
  });

  test('well past middle grey they flip', () {
    expect(
      foregroundBrightnessFor(0.40, current: Brightness.light),
      Brightness.dark,
    );
    expect(
      foregroundBrightnessFor(0.60, current: Brightness.dark),
      Brightness.light,
    );
  });
}
