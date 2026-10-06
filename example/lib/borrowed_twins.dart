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
  _ => null,
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
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 20),
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

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) => GlassScaffold(
    backgroundColor: Colors.white,
    tabBar: GlassTabBar(
      items: const [
        GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
        GlassTabBarItem(icon: CupertinoIcons.tray, label: 'Inbox', badge: '3'),
        GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
      ],
      selectedIndex: 0,
      onSelected: (_) {},
    ),
    body: const SizedBox.expand(),
  );
}
