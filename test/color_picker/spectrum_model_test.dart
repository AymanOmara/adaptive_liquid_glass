import 'package:adaptive_liquid_glass/src/color_picker/spectrum_model.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// UIColorPickerViewController's Spectrum page (iOS 26.4, measured): hue
/// runs down the page, red at the top and the bottom; across it the
/// colour fades from white at the start through the pure hue at the
/// centre to black at the end.
void main() {
  Color rgb(HSVColor c) => c.toColor();
  int ch(double v) => (v * 255).round();

  test('the centre column is the pure hue, top red', () {
    expect(spectrumColorAt(0.5, 0).toColor(), const Color(0xFFFF0000));
    expect(spectrumColorAt(0.5, 2 / 6).toColor(), const Color(0xFF00FF00));
    expect(spectrumColorAt(0.5, 4 / 6).toColor(), const Color(0xFF0000FF));
    expect(spectrumColorAt(0.5, 1).hue, moreOrLessEquals(0, epsilon: 1e-9));
  });

  test('white at the start, black at the end', () {
    expect(rgb(spectrumColorAt(0, 0.3)), const Color(0xFFFFFFFF));
    expect(rgb(spectrumColorAt(1, 0.3)), const Color(0xFF000000));
  });

  test("UIKit's measured shades: green row, a quarter and three quarters "
      'across', () {
    // Measured 152 (white side) and 102 (dark side) of 255.
    final light = spectrumColorAt(0.25, 2 / 6).toColor();
    expect(ch(light.r), closeTo(153, 3));
    expect(ch(light.g), 255);
    final dark = spectrumColorAt(0.75, 2 / 6).toColor();
    expect(ch(dark.g), closeTo(153, 3));
    expect(ch(dark.r), 0);
  });

  test("UIKit's hue ramp: half way from red to yellow is 0.41, not 0.5", () {
    final c = spectrumColorAt(0.5, 0.5 / 6).toColor();
    expect(ch(c.r), 255);
    expect(c.g, closeTo(0.409, 0.01));
  });

  test('positionOf inverts colorAt across the map', () {
    for (var u = 0.05; u < 1; u += 0.1) {
      for (var w = 0.0; w < 0.99; w += 0.07) {
        final p = spectrumPositionOf(spectrumColorAt(u, w));
        expect(p.dx, moreOrLessEquals(u, epsilon: 1e-6), reason: '$u,$w');
        expect(p.dy, moreOrLessEquals(w, epsilon: 1e-6), reason: '$u,$w');
      }
    }
  });

  test("UIKit's thumb for #FF383C sits at (0.395, 0.981) (measured)", () {
    final p = spectrumPositionOf(HSVColor.fromColor(const Color(0xFFFF383C)));
    expect(p.dx, closeTo(0.395, 0.01));
    expect(p.dy, closeTo(0.981, 0.01));
  });

  test('a colour off the map (greyed) lands on its nearer side', () {
    // Mostly white-ish: s 0.3, v 0.9 is placed by its saturation.
    final p = spectrumPositionOf(const HSVColor.fromAHSV(1, 120, 0.3, 0.9));
    expect(p.dx, lessThan(0.5));
    // Mostly dark: s 0.9, v 0.3 is placed by its value.
    final q = spectrumPositionOf(const HSVColor.fromAHSV(1, 120, 0.9, 0.3));
    expect(q.dx, greaterThan(0.5));
  });
}
