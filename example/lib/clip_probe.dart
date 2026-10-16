import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/material.dart';

/// Shaped clips around shader glass on Android's shared layer:
/// `flutter run -t lib/clip_probe.dart`. Each square glass carries an
/// orange stripe across its content; the rounded and oval clips must cut
/// both the glass and the stripe to their shape (left: unclipped).
void main() => runApp(
  const LiquidGlassTheme(
    data: LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
    child: MaterialApp(debugShowCheckedModeBanner: false, home: _Probe()),
  ),
);

class _Probe extends StatelessWidget {
  const _Probe();

  Widget _glass() => LiquidGlass(
    shape: const GlassShape.rect(0),
    child: SizedBox(
      width: 110,
      height: 110,
      child: Center(
        child: Container(height: 24, color: const Color(0xFFFF9500)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.pink, Colors.yellow, Colors.green],
          stops: [0, 0.33, 0.66, 1],
          tileMode: TileMode.repeated,
          end: Alignment(-0.6, -0.6),
        ),
      ),
      child: Center(
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _glass(),
            ClipRRect(borderRadius: BorderRadius.circular(36), child: _glass()),
            ClipOval(child: _glass()),
          ],
        ),
      ),
    ),
  );
}
