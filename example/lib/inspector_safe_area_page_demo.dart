import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoColors, CupertinoIcons;
import 'package:flutter/material.dart';

/// Twins of `InspectorReference`, `SafeAreaBarReference` and
/// `PageStyleReference` (`ios/Runner/NewComponentScenes.swift`). Null when
/// [scene] is not one of them.
Widget? inspectorSafeAreaPageTwin(String scene) => switch (scene) {
  'inspector' || 'inspectordark' => const InspectorDemo(openOnStart: true),
  'inspectortoggle' => const InspectorDemo(autoToggle: true),
  'safeareabar' || 'safeareabardark' => const SafeAreaBarDemo(),
  'pagestyle' || 'pagestylebackground' => const PageViewDemo(),
  _ => null,
};

/// Buttons that open the three demos; for the components page.
class InspectorSafeAreaPageLinks extends StatelessWidget {
  /// The three links.
  const InspectorSafeAreaPageLinks({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 12,
    children: [
      GlassButton(
        onPressed: () => _open(context, const InspectorDemo()),
        child: const Text('Inspector'),
      ),
      GlassButton(
        onPressed: () => _open(context, const SafeAreaBarDemo()),
        child: const Text('Safe-area bar'),
      ),
      GlassButton(
        onPressed: () => _open(context, const PageViewDemo()),
        child: const Text('Page view'),
      ),
    ],
  );
}

/// A notes list with an inspector: a sheet on a phone, a trailing column
/// on a tablet.
class InspectorDemo extends StatefulWidget {
  /// The demo.
  const InspectorDemo({
    super.key,
    this.openOnStart = false,
    this.autoToggle = false,
  });

  /// Opens the inspector half a second in, as the reference does.
  final bool openOnStart;

  /// Toggles it every 2.5 s, as the toggle reference does.
  final bool autoToggle;

  @override
  State<InspectorDemo> createState() => _InspectorDemoState();
}

class _InspectorDemoState extends State<InspectorDemo> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    if (widget.openOnStart || widget.autoToggle) {
      Future<void>.delayed(const Duration(milliseconds: 500), _tick);
    }
  }

  void _tick() {
    if (!mounted) return;
    setState(() => _shown = widget.autoToggle ? !_shown : true);
    if (widget.autoToggle) {
      Future<void>.delayed(const Duration(milliseconds: 2500), _tick);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Notes'),
      actions: [
        IconButton(
          onPressed: () => setState(() => _shown = !_shown),
          icon: const Icon(CupertinoIcons.info_circle),
        ),
      ],
    ),
    body: GlassInspector(
      isPresented: _shown,
      onPresentedChanged: (v) => setState(() => _shown = v),
      inspector: (_) => ListView(
        padding: const EdgeInsetsDirectional.all(16),
        children: const [
          GlassListSection(
            header: Text('Text'),
            children: [
              GlassListTile(title: Text('Font'), trailing: Text('SF Pro')),
              GlassListTile(title: Text('Size'), trailing: Text('17 pt')),
            ],
          ),
        ],
      ),
      child: ListView.builder(
        itemCount: 30,
        itemBuilder: (_, i) => ListTile(title: Text('Note ${i + 1}')),
      ),
    ),
  );
}

/// 40 alternating rows under a bar at the top and one at the bottom.
class SafeAreaBarDemo extends StatelessWidget {
  /// The demo.
  const SafeAreaBarDemo({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: CupertinoColors.white,
    child: GlassSafeAreaBar(
      edge: GlassSafeAreaEdge.bottom,
      bar: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        child: Row(
          children: [
            GlassButton(onPressed: () {}, child: const Text('3 drafts')),
            const Spacer(),
            GlassButton(onPressed: () {}, child: const Text('Compose')),
          ],
        ),
      ),
      child: GlassSafeAreaBar(
        edge: GlassSafeAreaEdge.top,
        bar: GlassButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Filter'),
        ),
        child: ListView.builder(
          itemCount: 40,
          itemBuilder: (_, i) => Container(
            height: 60,
            color: i.isEven ? Colors.orange : Colors.blue,
          ),
        ),
      ),
    ),
  );
}

/// Three coloured pages over glass page dots.
class PageViewDemo extends StatelessWidget {
  /// The demo.
  const PageViewDemo({super.key});

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: CupertinoColors.white,
    child: GlassPageView(
      children: [
        ColoredBox(
          color: Colors.orange,
          child: Center(child: Text('One')),
        ),
        ColoredBox(
          color: Colors.teal,
          child: Center(child: Text('Two')),
        ),
        ColoredBox(
          color: Colors.indigo,
          child: Center(child: Text('Three')),
        ),
      ],
    ),
  );
}
