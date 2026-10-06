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
        // Kept's History row behind the bar, so the lens refracts the same
        // page (positions and colours measured from the Kept recording;
        // below the separator Kept dims the page to about 7 %).
        Positioned(
          left: 16,
          top: 727.6,
          child: Container(
            width: 43.7,
            height: 43.7,
            decoration: BoxDecoration(
              color: const Color(0xFF00101A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              CupertinoIcons.doc_text,
              size: 24,
              color: Color(0xFF008AF2),
            ),
          ),
        ),
        const Positioned(
          left: 73,
          top: 727,
          child: _Line('Flight KE 902 · Gate 34 · Boarding'),
        ),
        const Positioned(left: 73, top: 752, child: _Line('18:40')),
        const Positioned(
          left: 72,
          top: 779,
          child: Icon(
            CupertinoIcons.pin_fill,
            size: 15,
            color: Color(0xFFE8913A),
          ),
        ),
        const Positioned(
          left: 92.7,
          top: 777,
          child: Text(
            '40 chars · 40 min ago · Notes',
            style: TextStyle(
              fontSize: 12.4,
              letterSpacing: 0.1,
              color: Color(0xFF8A8A8E),
            ),
          ),
        ),
        Positioned(
          left: 65.3,
          right: 16,
          top: 812.3,
          child: Container(height: 1, color: const Color(0xFF2C2C2E)),
        ),
        const Positioned(
          left: 73,
          top: 829,
          child: Text(
            'Dashboard metrics · Q3 review',
            style: TextStyle(fontSize: 15.3, color: Color(0xFF2A2A2A)),
          ),
        ),
        const Positioned(
          left: 72,
          top: 858,
          child: Text(
            '●  Work  31 chars · 1 hr ago · Maps',
            style: TextStyle(fontSize: 13.6, color: Color(0xFF121212)),
          ),
        ),
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
              selectedColor: const Color(0xFF1DAEFF), // Kept's accent
              selectedIndex: _tab,
              onSelected: (i) => setState(() => _tab = i),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 15.3, color: Color(0xFFF0F0F0)),
  );
}
