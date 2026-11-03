// Normal app fixture for real UIKit gestures, independent of WidgetTester.
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/tab_bar/native_system_tab_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const bitmap = bool.fromEnvironment('NATIVE_TAB_BITMAP');

/// The custom Flutter bar in native mode (a `labelMaxTextScale` leaves the
/// stock native bar), over the same photo.
const custom = bool.fromEnvironment('NATIVE_TAB_CUSTOM');

void main() => runApp(
  const MaterialApp(debugShowCheckedModeBanner: false, home: _TouchFixture()),
);

class _TouchFixture extends StatefulWidget {
  const _TouchFixture();
  @override
  State<_TouchFixture> createState() => _TouchFixtureState();
}

class _TouchFixtureState extends State<_TouchFixture> {
  int selected = 0;
  bool covered = false;
  bool dark = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final hosts = await const MethodChannel('adaptive_liquid_glass')
          .invokeMethod<int>('debugNativeTabHosts');
      debugPrint('NATIVE_TAB_HOSTS:$hosts');
      debugPrint('NATIVE_TAB_READY');
    });
  }

  void pick(int index) {
    setState(() => selected = index);
    debugPrint('NATIVE_TAB_PICK:$index');
  }

  @override
  // Material gives the custom bar's Flutter labels a text style.
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFF0000),
    child: Stack(
      children: [
        if (bitmap || custom)
          Positioned.fill(
            child: Image.asset(
              'assets/backgrounds/photo.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
        Positioned(
          left: 64,
          top: 790,
          width: 274,
          height: 62,
          child: bitmap || custom
              ? MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    platformBrightness: dark
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                  child: GlassTabBar(
                    items: const [
                      GlassTabBarItem(
                        icon: CupertinoIcons.house,
                        activeIcon: CupertinoIcons.house_fill,
                        label: 'Home',
                      ),
                      GlassTabBarItem(icon: Icons.music_note, label: 'Music'),
                      GlassTabBarItem(
                        icon: CupertinoIcons.gear_solid,
                        label: 'Settings',
                        badge: '2',
                      ),
                    ],
                    selectedIndex: selected,
                    onSelected: pick,
                    mode: GlassRenderMode.native,
                    labelMaxTextScale: custom ? 1 : null,
                  ),
                )
              : NativeSystemTabBar(
                  items: const [
                    NativeTabItem(label: 'Home', symbol: 'house.fill'),
                    NativeTabItem(label: 'Music', symbol: 'music.note'),
                    NativeTabItem(
                      label: 'Settings',
                      symbol: 'gearshape.fill',
                      badge: '2',
                    ),
                  ],
                  selectedIndex: selected,
                  onSelected: pick,
                  tint: null,
                  dark: dark,
                  width: 274,
                  height: 62,
                  fallback: const Text('Unsupported fixture layout'),
                ),
        ),
        Positioned(
          left: 20,
          top: 100,
          width: 120,
          height: 50,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => covered = !covered);
              debugPrint('NATIVE_TAB_COVER:$covered');
            },
            child: const ColoredBox(color: Colors.white),
          ),
        ),
        Positioned(
          left: 20,
          top: 170,
          width: 120,
          height: 50,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => dark = !dark);
              debugPrint('NATIVE_TAB_DARK:$dark');
            },
            child: const ColoredBox(color: Colors.black),
          ),
        ),
        if (covered)
          Positioned(
            left: 150,
            top: 790,
            width: 100,
            height: 62,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => debugPrint('NATIVE_TAB_OVERLAY'),
              child: const ColoredBox(color: Color(0xFF0000FF)),
            ),
          ),
      ],
    ),
  );
}
