part of 'list_chevron.dart';

class _ChevronPainter extends CustomPainter {
  _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // An open chevron hugging the glyph box; the stroke is inset by half
    // its width so the round caps stay inside the measured bounds.
    final s = ListMetrics.chevronStroke;
    final path = Path()
      ..moveTo(s / 2, s / 2)
      ..lineTo(size.width - s / 2, size.height / 2)
      ..lineTo(s / 2, size.height - s / 2);
    final paint = Paint()
      ..color = color
      ..strokeWidth = s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}
