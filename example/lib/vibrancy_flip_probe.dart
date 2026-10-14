import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Checks the backdrop orientation of the shader tab bar's vibrant labels:
/// `flutter run -t lib/vibrancy_flip_probe.dart`. The page is red but for
/// a blue band behind the bar's label row, so labels that sample the
/// backdrop upright tint blue and upside-down ones (which read the bar's
/// top, mirrored) red.
/// `--dart-define=PHOTO=true` puts the bar over `photo.png` instead.
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) => GlassScaffold(
    tabBar: GlassTabBar(
      items: const [
        GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
        GlassTabBarItem(icon: CupertinoIcons.music_note, label: 'Music'),
        GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
      ],
      selectedIndex: _tab,
      onSelected: (i) => setState(() => _tab = i),
      mode: GlassRenderMode.shader,
    ),
    body: const bool.fromEnvironment('PHOTO')
        ? Image.asset(
            'assets/backgrounds/photo.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : const Column(
            children: [
              Expanded(
                child: ColoredBox(
                  color: Color(0xFFFF0000),
                  child: SizedBox.expand(),
                ),
              ),
              // The bar's label row and below: blue.
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ColoredBox(color: Color(0xFF0000FF)),
              ),
            ],
          ),
  );
}
