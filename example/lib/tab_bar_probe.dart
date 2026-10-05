import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The tab bar laid out like Kept's (iOS 26.4, iPhone 17 Pro) for motion
/// comparison against it: `flutter run -t lib/tab_bar_probe.dart`.
void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
      ),
    ),
    home: const _Probe(),
  ),
);

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int _tab = 2;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFF000000),
    child: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 21,
          child: Center(
            child: GlassTabBar(
              items: const [
                GlassTabBarItem(
                  icon: CupertinoIcons.clock_fill,
                  label: 'History',
                ),
                GlassTabBarItem(
                  icon: CupertinoIcons.text_quote,
                  label: 'Snippets',
                ),
                GlassTabBarItem(
                  icon: CupertinoIcons.gear_solid,
                  label: 'Settings',
                ),
              ],
              selectedIndex: _tab,
              onSelected: (i) => setState(() => _tab = i),
            ),
          ),
        ),
      ],
    ),
  );
}
