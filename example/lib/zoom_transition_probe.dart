import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shader glass on pages pushed with the Zoom page transition, which
/// snapshots both pages. Pushes after 6 s with the animation slowed 40x;
/// `flutter run -t lib/zoom_transition_probe.dart`.
void main() => runApp(
  LiquidGlassTheme(
    data: const LiquidGlassThemeData(
      defaultMode: GlassRenderMode.shader,
      supportLiquidGlassOnAndroid: true,
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.android: ZoomPageTransitionsBuilder()},
        ),
      ),
      home: const _Page(label: 'First', hue: 200, next: true),
    ),
  ),
);

class _Page extends StatefulWidget {
  const _Page({required this.label, required this.hue, this.next = false});

  final String label;
  final double hue;
  final bool next;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    if (!widget.next) return;
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      timeDilation = 40;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const _Page(label: 'Second', hue: 20),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = HSVColor.fromAHSV(1, widget.hue, 0.7, 0.9).toColor();
    final b = HSVColor.fromAHSV(1, (widget.hue + 90) % 360, 0.8, 0.5).toColor();
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [a, b],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (
                var i = 0;
                i < const int.fromEnvironment("GROUPS", defaultValue: 4);
                i++
              )
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: LiquidGlass(
                    child: SizedBox(
                      width: 200,
                      height: 48,
                      child: Center(child: Text('${widget.label} $i')),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
