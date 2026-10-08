import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Twins of the SwiftUI references for the components added in
/// feat/borrow-lgw (`ios/Runner/ControlScenes.swift`, same layout), for
/// `tool/reference/side_by_side.sh`. Null when [scene] is not one of them.
Widget? borrowedTwin(String scene) => switch (scene) {
  'textfield' => const _TextFields(),
  'list' => const _List(),
  'progress' => const _Progress(),
  'pagecontrol' => const _PageControl(),
  'actionsheet' => const _ActionSheet(),
  'badge' => const _Badge(),
  'badgemore' => const _Badge(more: true),
  'tabbar' => const _TabBar(photo: false, dark: false),
  'tabbarphoto' => const _TabBar(photo: true, dark: false),
  'tabbardark' => const _TabBar(photo: false, dark: true),
  'tabbarphotodark' => const _TabBar(photo: true, dark: true),
  'accessorytext' => const _AccessoryText(accessory: true),
  'tabbartext' => const _AccessoryText(accessory: false),
  'lensreach' => const _LensReach(),
  _ => null,
};

/// The tab bar's path for `-mode native|shader`: the bar keeps to shader
/// glass on iOS 26 unless asked, so the twin asks; null under `auto`.
GlassRenderMode? twinBarMode(BuildContext context) =>
    switch (LiquidGlassTheme.of(context).defaultMode) {
      GlassRenderMode.auto => null,
      final mode => mode,
    };

/// [child] centred at ([x], [y]) in screen points.
Widget _at(double x, double y, Widget child) => Positioned(
  left: x - 201,
  top: y - 100,
  width: 402,
  height: 200,
  child: Center(child: child),
);

/// [child] in dark mode.
Widget _dark(BuildContext context, Widget child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(platformBrightness: Brightness.dark),
  child: CupertinoTheme(
    data: const CupertinoThemeData(brightness: Brightness.dark),
    child: child,
  ),
);

/// White page with a black band at y 300-460, [pair] centred at y 160 and,
/// in dark, at y 380.
Widget _lightAndDark(BuildContext context, Widget pair) => ColoredBox(
  color: Colors.white,
  child: Stack(
    children: [
      const Positioned(
        left: 0,
        right: 0,
        top: 300,
        height: 160,
        child: ColoredBox(color: Colors.black),
      ),
      _at(201, 160, pair),
      _at(201, 380, _dark(context, pair)),
    ],
  ),
);

class _TextFields extends StatelessWidget {
  const _TextFields();

  @override
  Widget build(BuildContext context) => _lightAndDark(
    context,
    SizedBox(
      width: 362,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const GlassTextField(placeholder: 'Name'),
          const SizedBox(height: 24),
          GlassTextField.password(
            placeholder: 'Password',
            controller: TextEditingController(text: 'secret'),
          ),
        ],
      ),
    ),
  );
}

class _List extends StatefulWidget {
  const _List();

  @override
  State<_List> createState() => _ListState();
}

class _ListState extends State<_List> {
  bool _on = true;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
    child: ListView(
      // Puts the header where SwiftUI's List does (measured).
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 10.67),
      children: [
        GlassListSection(
          header: const Text('Connections'),
          footer: const Text('Footer text'),
          children: [
            const GlassListTile(
              leading: Icon(CupertinoIcons.wifi),
              title: Text('Wi-Fi'),
              value: 'Home',
            ),
            GlassListTile(
              leading: const Icon(CupertinoIcons.gear),
              title: const Text('General'),
              chevron: true,
              onTap: () {},
            ),
            GlassListTile(
              leading: const Icon(CupertinoIcons.airplane),
              title: const Text('Airplane Mode'),
              trailing: GlassToggle(
                value: _on,
                onChanged: (v) => setState(() => _on = v),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress();

  @override
  Widget build(BuildContext context) => _lightAndDark(
    context,
    const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 300, child: GlassProgressIndicator(value: 0.4)),
        SizedBox(height: 40),
        GlassProgressIndicator.circular(),
      ],
    ),
  );
}

class _PageControl extends StatefulWidget {
  const _PageControl();

  @override
  State<_PageControl> createState() => _PageControlState();
}

class _PageControlState extends State<_PageControl> {
  final _controller = PageController(initialPage: 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      PageView(
        controller: _controller,
        children: [
          for (var i = 0; i < 5; i++)
            ColoredBox(
              color: Color.from(
                alpha: 1,
                red: 0.85 - i * 0.05,
                green: 0.85 - i * 0.05,
                blue: 0.85 - i * 0.05,
              ),
            ),
        ],
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
        child: Center(
          child: GlassPageControl(count: 5, controller: _controller),
        ),
      ),
    ],
  );
}

class _ActionSheet extends StatefulWidget {
  const _ActionSheet();

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      showGlassActionSheet(
        context: context,
        title: 'Delete photo?',
        message: 'This photo will be removed from all your devices.',
        actions: const [
          GlassDialogAction(label: 'Delete', role: GlassButtonRole.destructive),
          GlassDialogAction(label: 'Duplicate'),
        ],
        cancel: const GlassDialogAction(
          label: 'Cancel',
          role: GlassButtonRole.cancel,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Colors.white, child: SizedBox.expand());
}

/// `-controls badge`: Inbox with a count of 3. `badgemore`: an empty
/// badge, 42 and "New".
class _Badge extends StatefulWidget {
  const _Badge({this.more = false});

  final bool more;

  @override
  State<_Badge> createState() => _BadgeState();
}

/// Keeps the selection, as SwiftUI's `TabView` does.
class _BadgeState extends State<_Badge> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => GlassScaffold(
    backgroundColor: Colors.white,
    tabBar: GlassTabBar(
      items: [
        GlassTabBarItem(
          icon: CupertinoIcons.house_fill,
          label: 'Home',
          badge: widget.more ? '' : null,
        ),
        GlassTabBarItem(
          icon: CupertinoIcons.tray_fill,
          label: 'Inbox',
          badge: widget.more ? '42' : '3',
        ),
        GlassTabBarItem(
          icon: CupertinoIcons.gear,
          label: 'Settings',
          badge: widget.more ? 'New' : null,
        ),
      ],
      selectedIndex: _tab,
      onSelected: (i) => setState(() => _tab = i),
      mode: twinBarMode(context),
    ),
    body: const SizedBox.expand(),
  );
}

/// `-controls tabbar` / `tabbarphoto` / `tabbardark` / `tabbarphotodark`:
/// Home, Music, Settings with Home selected, over a white (or, dark, black)
/// page or the full-screen `photo.png`.
class _TabBar extends StatefulWidget {
  const _TabBar({required this.photo, required this.dark});

  final bool photo;
  final bool dark;

  @override
  State<_TabBar> createState() => _TabBarState();
}

/// Keeps the selection, as SwiftUI's `TabView` does, so a recorded drag
/// ends on the same tab in both.
class _TabBarState extends State<_TabBar> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final scaffold = GlassScaffold(
      backgroundColor: widget.dark ? Colors.black : Colors.white,
      tabBar: GlassTabBar(
        items: const [
          GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
          GlassTabBarItem(icon: CupertinoIcons.music_note, label: 'Music'),
          GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
        ],
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
        mode: twinBarMode(context),
      ),
      body: widget.photo
          ? Image.asset(
              'assets/backgrounds/photo.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            )
          : const SizedBox.expand(),
    );
    return widget.dark ? _dark(context, scaffold) : scaffold;
  }
}

/// `-controls accessorytext`: dark, the accessory and the tab bar over rows
/// of white text, one every 34 pt from the top; `tabbartext` without the
/// accessory.
class _AccessoryText extends StatefulWidget {
  const _AccessoryText({required this.accessory});

  final bool accessory;

  @override
  State<_AccessoryText> createState() => _AccessoryTextState();
}

class _AccessoryTextState extends State<_AccessoryText> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => _dark(
    context,
    GlassScaffold(
      backgroundColor: Colors.black,
      tabBar: GlassTabBar(
        items: const [
          GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
          GlassTabBarItem(icon: CupertinoIcons.music_note, label: 'Music'),
          GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
        ],
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
        mode: twinBarMode(context),
      ),
      bottomAccessory: !widget.accessory
          ? null
          : const GlassBottomAccessory(
              child: Row(
                children: [
                  Icon(CupertinoIcons.music_note),
                  SizedBox(width: 8),
                  Text('Now Playing'),
                  Spacer(),
                  Icon(CupertinoIcons.play_fill),
                ],
              ),
            ),
      body: Padding(
        padding: const EdgeInsetsDirectional.only(start: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 25; i++)
              const SizedBox(
                height: 34,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'Day Week Month Day Week',
                    style: TextStyle(fontSize: 22, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// `-controls lensreach`: dark, the tab bar over a black page with a hue
/// ramp from y 789 (hue 0) up to y 681 (hue 0.75), in screen coordinates.
class _LensReach extends StatefulWidget {
  const _LensReach();

  @override
  State<_LensReach> createState() => _LensReachState();
}

class _LensReachState extends State<_LensReach> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => _dark(
    context,
    GlassScaffold(
      backgroundColor: Colors.black,
      tabBar: GlassTabBar(
        items: const [
          GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
          GlassTabBarItem(icon: CupertinoIcons.music_note, label: 'Music'),
          GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
        ],
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
        mode: twinBarMode(context),
      ),
      body: const CustomPaint(painter: _HueRamp(), size: Size.infinite),
    ),
  );
}

class _HueRamp extends CustomPainter {
  const _HueRamp();

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 216; i++) {
      final y = 789.0 - (i + 1) * 0.5;
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 0.5),
        Paint()
          ..color = HSVColor.fromAHSV(1, i / 216 * 0.75 * 360, 1, 1).toColor(),
      );
    }
  }

  @override
  bool shouldRepaint(_HueRamp old) => false;
}
