import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/material.dart';

/// Glass of different frosts side by side: a large regular card, small
/// regular buttons and clear capsules, each its own group, over a photo or
/// text (`--dart-define=BG=text`). On Android they share one stratum of
/// the shared layer; `--dart-define=ADAPTIVE_LIQUID_GLASS_SHARED_LAYER=off`
/// draws each group with its own blur, the reference.
/// `flutter run --profile -t lib/blur_mix_probe.dart`.
void main() => runApp(
  const LiquidGlassTheme(
    data: LiquidGlassThemeData(
      defaultMode: GlassRenderMode.shader,
      supportLiquidGlassOnAndroid: true,
    ),
    child: MaterialApp(debugShowCheckedModeBanner: false, home: _Probe()),
  ),
);

const String _bg = String.fromEnvironment('BG', defaultValue: 'photo');

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) {
    Widget small(Glass glass) =>
        LiquidGlass(glass: glass, child: const SizedBox(width: 44, height: 44));
    Widget capsule() => const LiquidGlass(
      glass: Glass.clear,
      child: SizedBox(width: 120, height: 44),
    );
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/backgrounds/$_bg.png', fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LiquidGlass(
                    child: SizedBox(width: double.infinity, height: 220),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      for (var i = 0; i < 4; i++) ...[
                        small(Glass.regular),
                        const SizedBox(width: 24),
                      ],
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [capsule(), const SizedBox(width: 24), capsule()],
                  ),
                  const SizedBox(height: 32),
                  const LiquidGlass(
                    glass: Glass.clear,
                    child: SizedBox(width: double.infinity, height: 160),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
