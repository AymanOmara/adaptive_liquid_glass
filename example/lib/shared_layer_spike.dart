import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/material.dart';

/// Memory probe for the shared glass layer (see
/// docs/superpowers/plans/2026-10-15-shared-glass-layer.md):
/// `flutter run --profile -t lib/shared_layer_spike.dart
/// --dart-define=MODE=per|shared|none --dart-define=N=10`, then sample
/// `adb shell dumpsys meminfo <pkg> | grep "GL mtrack"`.
///
/// - `per`: N glass shapes, each in its own group (one backdrop filter and
///   one shader pass each, today's cost).
/// - `shared`: the same N shapes as members of one group (one backdrop
///   filter, one shader pass drawing N shapes).
/// - `none`: the photo only.
///
/// The shapes drift slowly so every frame repaints the glass.
void main() => runApp(
  const LiquidGlassTheme(
    data: LiquidGlassThemeData(
      defaultMode: GlassRenderMode.shader,
      androidShaderBudget: null,
    ),
    child: MaterialApp(debugShowCheckedModeBanner: false, home: _Spike()),
  ),
);

const String _mode = String.fromEnvironment('MODE', defaultValue: 'shared');
const int _n = int.fromEnvironment('N', defaultValue: 10);

class _Spike extends StatefulWidget {
  const _Spike();

  @override
  State<_Spike> createState() => _SpikeState();
}

class _SpikeState extends State<_Spike> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Widget _shape(int i) => LiquidGlass(
    shape: const GlassShape.capsule(),
    child: SizedBox(
      width: 120,
      height: 50,
      child: Center(child: Text('$i')),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final glass = AnimatedBuilder(
      animation: _drift,
      builder: (context, _) => Stack(
        children: [
          for (var i = 0; i < _n; i++)
            Positioned(
              left: 20.0 + (i % 2) * 180 + _drift.value * 30,
              top: 60.0 + (i ~/ 2) * 140,
              child: _shape(i),
            ),
        ],
      ),
    );
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/backgrounds/photo.png', fit: BoxFit.cover),
          if (_mode == 'per') glass,
          if (_mode == 'shared') GlassGroup(child: glass),
        ],
      ),
    );
  }
}
