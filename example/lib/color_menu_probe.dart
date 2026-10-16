import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/material.dart';

/// The colour sheet's saved colours on Android with the iOS look:
/// `flutter run -t lib/color_menu_probe.dart`; long-press a saved colour
/// for its Delete menu.
void main() => runApp(
  const LiquidGlassTheme(
    data: LiquidGlassThemeData(defaultMode: GlassRenderMode.shader),
    child: MaterialApp(debugShowCheckedModeBanner: false, home: _Probe()),
  ),
);

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  Color _accent = Colors.blue;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassColorPicker(
          label: const Text('Accent'),
          value: _accent,
          onChanged: (c) => setState(() => _accent = c),
        ),
      ),
    ),
  );
}
