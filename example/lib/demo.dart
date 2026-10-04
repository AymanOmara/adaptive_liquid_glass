import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';

/// A quick look at still glass over a busy, photo-like backdrop.
class Demo extends StatelessWidget {
  /// Creates the demo.
  const Demo({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [
                Color(0xFF1E3A8A),
                Color(0xFF7C3AED),
                Color(0xFFDB2777),
                Color(0xFFF59E0B),
                Color(0xFF10B981),
                Color(0xFF0EA5E9),
              ],
            ),
          ),
        ),
        for (var i = 0; i < 30; i++)
          PositionedDirectional(
            start: 0,
            end: 0,
            top: i * 32.0,
            height: 6,
            child: const ColoredBox(color: Color(0xCCFFFFFF)),
          ),
        const Center(
          child: LiquidGlass(
            shape: GlassShape.rect(28),
            child: SizedBox(
              width: 280,
              height: 160,
              child: Center(
                child: Text(
                  'Liquid Glass',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
            ),
          ),
        ),
        const PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 60,
          child: Center(
            child: GlassGroup(
              spacing: 20,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiquidGlass(child: SizedBox(width: 72, height: 52)),
                  SizedBox(width: 12),
                  LiquidGlass(child: SizedBox(width: 72, height: 52)),
                  SizedBox(width: 12),
                  LiquidGlass(child: SizedBox(width: 72, height: 52)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
