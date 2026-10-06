import 'package:flutter/cupertino.dart';

/// Fades [child] out over the [rim] at its leading and trailing ends.
class RimFade extends StatelessWidget {
  /// Fades [child] over [rim] at each end.
  const RimFade({super.key, required this.rim, required this.child});

  /// The width of each fade, in logical pixels.
  final double rim;

  /// The faded content.
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      Gradient fade(Axis axis) {
        final extent = axis == Axis.horizontal
            ? constraints.maxWidth
            : constraints.maxHeight;
        final f = extent <= 0 ? 0.5 : (rim / extent).clamp(0.0, 0.5);
        const clear = Color(0x00000000);
        const solid = Color(0xFF000000);
        return LinearGradient(
          begin: axis == Axis.horizontal
              ? Alignment.centerLeft
              : Alignment.topCenter,
          end: axis == Axis.horizontal
              ? Alignment.centerRight
              : Alignment.bottomCenter,
          colors: const [clear, solid, solid, clear],
          stops: [0, f, 1 - f, 1],
        );
      }

      return ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => fade(Axis.horizontal).createShader(bounds),
        child: child,
      );
    },
  );
}
