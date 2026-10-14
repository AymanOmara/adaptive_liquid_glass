part of 'hsv_spectrum.dart';

class _SpectrumPainter extends CustomPainter {
  const _SpectrumPainter(this.hue);

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [
            GlassColors.white,
            HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GlassColors.transparent, GlassColors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SpectrumPainter oldDelegate) => oldDelegate.hue != hue;
}
