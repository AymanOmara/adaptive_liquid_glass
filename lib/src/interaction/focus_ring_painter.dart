part of 'glass_focus_ring.dart';

class _FocusRingPainter extends CustomPainter {
  _FocusRingPainter({required this.border, required this.color});

  final OutlinedBorder border;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).inflate(_outset);
    canvas.drawPath(
      border.getOuterPath(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = FocusRingMetrics.width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.border != border || old.color != color;
}
