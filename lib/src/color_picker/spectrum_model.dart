import 'package:flutter/painting.dart';

/// UIColorPickerViewController's Spectrum map (iOS 26.4, measured from
/// `colorsheet_spectrum.png`): hue runs down the page in six equal bands
/// (red, yellow, green, cyan, blue, magenta, red again), and across it
/// the colour fades from white at the start through the pure hue at the
/// centre to black at the end. Both fades follow [spectrumShade] and the
/// hue within a band follows [spectrumRamp], not straight lines.

/// The changing channel across one hue band (red to yellow: green), at
/// twelfths of the band (measured, six bands averaged).
const List<double> spectrumRamp = [
  0, 0.01, 0.046, 0.101, 0.18, 0.29, 0.409, 0.542, 0.688, 0.81, 0.91, //
  0.978, 1,
];

/// The fade from the centre outwards, at twelfths of a half: the white
/// side's lowest channel and the dark side's highest, read from the
/// outer edge (1) to the centre (0) reversed (measured, six rows averaged;
/// the two halves match within 0.005).
const List<double> spectrumShade = [
  1, 0.969, 0.922, 0.861, 0.784, 0.698, 0.6, 0.494, 0.384, 0.27, 0.161, //
  0.06, 0,
];

double _at(List<double> lut, double t) {
  final x = t.clamp(0.0, 1.0) * (lut.length - 1);
  final i = x.floor().clamp(0, lut.length - 2);
  final f = x - i;
  return lut[i] + (lut[i + 1] - lut[i]) * f;
}

/// The t at which the monotonic [lut] reaches [v].
double _inverse(List<double> lut, double v) {
  final rising = lut.last > lut.first;
  final n = lut.length - 1;
  for (var i = 0; i < n; i++) {
    final a = lut[i], b = lut[i + 1];
    final inside = rising ? v >= a && v <= b : v <= a && v >= b;
    if (inside) return (i + (b == a ? 0 : (v - a) / (b - a))) / n;
  }
  return (rising ? v < lut.first : v > lut.first) ? 0 : 1;
}

/// The colour at [u] across (0 start, 1 end) and [w] down (0 top, 1
/// bottom) the map.
HSVColor spectrumColorAt(double u, double w) {
  final band = (w.clamp(0.0, 1.0) * 6).floor().clamp(0, 5);
  final t = w.clamp(0.0, 1.0) * 6 - band;
  final within = band.isEven
      ? _at(spectrumRamp, t)
      : 1 - _at(spectrumRamp, 1 - t);
  final hue = 60 * (band + within) % 360;
  final x = u.clamp(0.0, 1.0);
  return x <= 0.5
      ? HSVColor.fromAHSV(1, hue, 1 - _at(spectrumShade, 2 * x), 1)
      : HSVColor.fromAHSV(1, hue, 1, _at(spectrumShade, 2 * x - 1));
}

/// Where [color] sits on the map, as fractions across and down. A colour
/// off the map (both whitened and darkened) goes to the side of the
/// larger change.
Offset spectrumPositionOf(HSVColor color) {
  final h = color.hue % 360;
  final band = (h / 60).floor().clamp(0, 5);
  final within = h / 60 - band;
  final t = band.isEven
      ? _inverse(spectrumRamp, within)
      : 1 - _inverse(spectrumRamp, 1 - within);
  final w = (band + t) / 6;
  final whitened = 1 - color.saturation;
  final darkened = 1 - color.value;
  final u = whitened >= darkened
      ? _inverse(spectrumShade, whitened) / 2
      : 0.5 + _inverse(spectrumShade, color.value) / 2;
  return Offset(u, w);
}
