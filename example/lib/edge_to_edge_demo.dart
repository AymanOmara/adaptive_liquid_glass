import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

// The edge-to-edge Material tab bar and GlassLargeTitleScrollView:
// `flutter run -t lib/edge_to_edge_demo.dart`.
// Tab 1: the fix (title collapses). Tab 2: the old trap (list in
// SliverFillRemaining, title stays). The FAB toggles floating/edge to edge.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdaptiveLiquidGlass.initialize();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: const _Demo(),
    ),
  );
}

class _Demo extends StatefulWidget {
  const _Demo();

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  int _tab = 0;
  bool _edge = true;

  static Widget _rows(String prefix) => ListView.builder(
    itemCount: 60,
    itemBuilder: (_, i) => ListTile(title: Text('$prefix row $i')),
  );

  @override
  Widget build(BuildContext context) => GlassScaffold(
    tabBar: GlassTabBar(
      materialStyle: _edge
          ? GlassMaterialTabBarStyle.edgeToEdge
          : GlassMaterialTabBarStyle.floating,
      items: const [
        GlassTabBarItem(icon: CupertinoIcons.check_mark, label: 'Fixed'),
        GlassTabBarItem(icon: CupertinoIcons.xmark, label: 'Old'),
      ],
      selectedIndex: _tab,
      onSelected: (i) => setState(() => _tab = i),
      onSearch: () => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Search tapped'))),
    ),
    body: Stack(
      children: [
        _tab == 0
            ? GlassLargeTitleScrollView(
                navigationBar: const SliverGlassNavigationBar(
                  largeTitle: Text('Directory'),
                ),
                body: _rows('Fixed'),
              )
            : CustomScrollView(
                slivers: [
                  const SliverGlassNavigationBar(largeTitle: Text('Services')),
                  SliverFillRemaining(child: _rows('Old')),
                ],
              ),
        // Below GlassScaffold, so the padding clears its tab bar.
        Builder(
          builder: (context) => PositionedDirectional(
            end: 16,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: FloatingActionButton.extended(
              onPressed: () => setState(() => _edge = !_edge),
              label: Text(_edge ? 'Edge to edge' : 'Floating'),
            ),
          ),
        ),
      ],
    ),
  );
}
