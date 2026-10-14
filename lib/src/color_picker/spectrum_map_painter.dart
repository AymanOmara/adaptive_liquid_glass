part of 'spectrum_map.dart';

/// Paints [spectrumColorAt]: the hue bands down the map, then white
/// fading out to the centre and black fading in from it, each with the
/// measured curves as gradient stops.
class _SpectrumMapPainter extends CustomPainter {
  const _SpectrumMapPainter();

  static final List<Color> _hues = [
    for (var i = 0; i < 6 * (spectrumRamp.length - 1); i++)
      spectrumColorAt(0.5, i / (6 * (spectrumRamp.length - 1))).toColor(),
    spectrumColorAt(0.5, 1).toColor(),
  ];

  static final List<double> _hueStops = [
    for (var i = 0; i < _hues.length; i++) i / (_hues.length - 1),
  ];

  static final int _n = spectrumShade.length - 1;

  static final List<Color> _shades = [
    for (var i = 0; i <= _n; i++)
      GlassColors.white.withValues(alpha: spectrumShade[i]),
    for (var i = 0; i <= _n; i++)
      GlassColors.black.withValues(alpha: 1 - spectrumShade[i]),
  ];

  static final List<double> _shadeStops = [
    for (var i = 0; i <= _n; i++) i / _n / 2,
    for (var i = 0; i <= _n; i++) 0.5 + i / _n / 2,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas
      ..drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _hues,
            stops: _hueStops,
          ).createShader(rect),
      )
      ..drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: _shades,
            stops: _shadeStops,
          ).createShader(rect),
      );
  }

  @override
  bool shouldRepaint(_SpectrumMapPainter oldDelegate) => false;
}
