import 'package:flutter/widgets.dart';

/// How far past the middle grey a backdrop must go before the labels on it
/// flip: a backdrop near middle grey keeps the labels it has.
const double kForegroundHysteresis = 0.08;

/// The backdrop brightness labels follow for a sampled mean [luminance],
/// given the brightness they follow now ([current]).
Brightness foregroundBrightnessFor(double luminance, {Brightness? current}) {
  return switch (current) {
    Brightness.light when luminance > 0.5 - kForegroundHysteresis =>
      Brightness.light,
    Brightness.dark when luminance < 0.5 + kForegroundHysteresis =>
      Brightness.dark,
    _ => luminance >= 0.5 ? Brightness.light : Brightness.dark,
  };
}
