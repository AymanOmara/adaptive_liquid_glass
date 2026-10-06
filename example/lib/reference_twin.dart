import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// `flutter run -t lib/reference_twin.dart --dart-define=SCENE=<name>`, or
/// the example app launched with `-twin <name>`:
/// this package's components laid out exactly as the SwiftUI reference
/// scenes in `ios/Runner/ControlScenes.swift`, so
/// `tool/reference/measure_components.py` measures both the same way.
/// Scenes: controls, toolbar, accessory, sheet, menu, search, swipe,
/// swipetall.
void main() => runApp(const ReferenceTwin());

/// The twin app.
class ReferenceTwin extends StatelessWidget {
  /// Creates the app.
  const ReferenceTwin({
    super.key,
    this.scene = const String.fromEnvironment(
      'SCENE',
      defaultValue: 'controls',
    ),
    this.mode,
  });

  /// The scene to show; the main app passes `-twin <name>` here.
  final String scene;

  /// The glass path (`-mode shader|native|auto`); null is the default.
  final String? mode;

  @override
  Widget build(BuildContext context) => LiquidGlassTheme(
    data: LiquidGlassThemeData(
      defaultMode: switch (mode) {
        'shader' => GlassRenderMode.shader,
        'native' => GlassRenderMode.native,
        _ => GlassRenderMode.auto,
      },
    ),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      themeMode: ThemeMode.light,
      home: switch (scene) {
        'toolbar' => const _Toolbar(),
        'accessory' => const _Accessory(),
        'sheet' => const _Sheet(),
        'menu' => const _Menu(),
        'search' => const _Search(),
        'swipe' => const _Swipe(tall: false),
        'swipetall' => const _Swipe(tall: true),
        _ => const _Controls(),
      },
    ),
  );
}

/// [child] centred at ([x], [y]) in screen points.
Widget _at(double x, double y, Widget child) => Positioned(
  left: x - 200,
  top: y - 100,
  width: 400,
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

class _Controls extends StatefulWidget {
  const _Controls();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  bool _on = true;
  bool _off = false;
  double _value = 0.5;
  int _segment = 1;

  Widget get _picker => SizedBox(
    width: 300,
    child: GlassSegmentedControl<int>(
      segments: const [
        GlassSegment(value: 0, label: Text('Day')),
        GlassSegment(value: 1, label: Text('Week')),
        GlassSegment(value: 2, label: Text('Month')),
      ],
      selected: _segment,
      onChanged: (v) => setState(() => _segment = v),
    ),
  );

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 450,
          height: 100,
          child: ColoredBox(color: Colors.black),
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 600,
          height: 200,
          child: ColoredBox(color: Colors.black),
        ),
        _at(
          201,
          100,
          GlassToggle(value: _on, onChanged: (v) => setState(() => _on = v)),
        ),
        _at(
          201,
          200,
          GlassToggle(value: _off, onChanged: (v) => setState(() => _off = v)),
        ),
        _at(
          201,
          300,
          SizedBox(
            width: 300,
            child: GlassSlider(
              value: _value,
              onChanged: (v) => setState(() => _value = v),
            ),
          ),
        ),
        _at(201, 400, _picker),
        _at(201, 500, _dark(context, _picker)),
        _at(
          201,
          640,
          _dark(
            context,
            GlassToggle(
              value: _off,
              onChanged: (v) => setState(() => _off = v),
            ),
          ),
        ),
        _at(
          201,
          740,
          _dark(
            context,
            SizedBox(
              width: 300,
              child: GlassSlider(
                value: _value,
                onChanged: (v) => setState(() => _value = v),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context) => GlassScaffold(
    backgroundColor: Colors.white,
    toolbar: GlassToolbar(
      children: [
        GlassButton.icon(
          onPressed: () {},
          icon: CupertinoIcons.reply,
          semanticLabel: 'Reply',
        ),
        GlassButton.icon(
          onPressed: () {},
          icon: CupertinoIcons.flag,
          semanticLabel: 'Flag',
        ),
        const GlassToolbarSpacer(),
        GlassButton.icon(
          onPressed: () {},
          icon: CupertinoIcons.square_pencil,
          semanticLabel: 'Compose',
        ),
      ],
    ),
    body: const SizedBox.expand(),
  );
}

class _Accessory extends StatelessWidget {
  const _Accessory();

  @override
  Widget build(BuildContext context) => GlassScaffold(
    backgroundColor: Colors.white,
    tabBar: GlassTabBar(
      items: const [
        GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
        GlassTabBarItem(icon: CupertinoIcons.music_note, label: 'Music'),
        GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
      ],
      selectedIndex: 0,
      onSelected: (_) {},
    ),
    bottomAccessory: const GlassBottomAccessory(
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
    body: const SizedBox.expand(),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet();

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => showGlassSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const SizedBox(
          // SwiftUI's medium detent: the sheet's top at 415 pt.
          height: 874 - 415 - 8 - 9.67,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Glass sheet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: Color(0xFF808080), child: SizedBox.expand());
}

class _Menu extends StatelessWidget {
  const _Menu();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF808080),
    extendBodyBehindAppBar: true,
    appBar: GlassNavigationBar(
      actions: [
        GlassMenuButton(
          icon: CupertinoIcons.ellipsis,
          semanticLabel: 'More',
          items: [
            GlassMenuItem(
              label: 'Copy',
              icon: CupertinoIcons.doc_on_doc,
              onSelected: () {},
            ),
            GlassMenuItem(
              label: 'Share',
              icon: CupertinoIcons.square_arrow_up,
              onSelected: () {},
            ),
            GlassMenuItem(
              label: 'Delete',
              icon: CupertinoIcons.trash,
              destructive: true,
              onSelected: () {},
            ),
          ],
        ),
      ],
    ),
    body: const SizedBox.expand(),
  );
}

class _Search extends StatelessWidget {
  const _Search();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFF2F2F7),
    child: Stack(
      children: [
        // SwiftUI floats the field 28 pt from the sides and bottom.
        Positioned(left: 28, right: 28, bottom: 28, child: GlassSearchField()),
      ],
    ),
  );
}

class _Swipe extends StatelessWidget {
  const _Swipe({required this.tall});

  final bool tall;

  @override
  Widget build(BuildContext context) {
    // The rows start where SwiftUI's plain List puts them: row 1 at 116
    // (54-pt rows) or 132.67 (70.67-pt rows).
    final height = tall ? 70.67 : 54.0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.only(top: (tall ? 132.67 : 116) - height),
        children: [
          for (var i = 0; i < 12; i++)
            GlassSwipeActions(
              key: ValueKey(i),
              leading: [
                GlassSwipeAction(
                  icon: CupertinoIcons.pin_fill,
                  label: 'Pin',
                  color: GlassSystemColors.orange,
                  onPressed: () {},
                ),
              ],
              trailing: [
                GlassSwipeAction(
                  icon: CupertinoIcons.trash,
                  label: 'Delete',
                  color: GlassSystemColors.red,
                  onPressed: () {},
                ),
                GlassSwipeAction(
                  icon: CupertinoIcons.square_arrow_up,
                  label: 'Share',
                  color: GlassSystemColors.blue,
                  onPressed: () {},
                ),
              ],
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 16),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.doc_text),
                      const SizedBox(width: 8),
                      Text('Item $i', style: const TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
