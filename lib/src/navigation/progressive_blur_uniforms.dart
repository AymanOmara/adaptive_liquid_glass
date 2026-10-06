import 'package:flutter/painting.dart';

/// The user floats of `progressive_blur.frag` (from float index 2, after
/// the engine's `uSize`) for one blur pass over a region at [origin]
/// (global logical px) of [size], in shader texture space (screen device
/// px). [axis] is 0 for the horizontal pass, 1 for the vertical one.
List<double> progressiveBlurUniforms({
  required Offset origin,
  required Size size,
  required double devicePixelRatio,
  required double maxSigma,
  required double falloff,
  required double axis,
}) => [
  maxSigma * devicePixelRatio,
  falloff,
  axis,
  origin.dx * devicePixelRatio,
  origin.dy * devicePixelRatio,
  size.width * devicePixelRatio,
  size.height * devicePixelRatio,
];
