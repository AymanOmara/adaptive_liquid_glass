import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Twins of the SwiftUI references for the newer components
/// (`ios/Runner/NewComponentScenes.swift`, same layout), for
/// `tool/reference/side_by_side.sh`. Null when [scene] is not one of them.
Widget? newComponentTwin(String scene) => switch (scene) {
  'disclosure' => const _Disclosure(),
  'emptystate' => const _EmptyState(),
  'emptystate2' => const _EmptyStateSwap(),
  'fullscreencover' => const _FullScreenCover(),
  'gauge' => const _Gauge(),
  _ => null,
};

/// The buttons' no-op, as the SwiftUI scene's empty `Button` actions.
void _noop() {}

/// [child] centred at ([x], [y]) in screen points.
Widget _at(double x, double y, Widget child) => Positioned(
  left: x - 201,
  top: y - 200,
  width: 402,
  height: 400,
  child: Center(child: child),
);

class _Disclosure extends StatelessWidget {
  const _Disclosure();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
    child: ListView(
      // Puts the header where SwiftUI's List does (measured).
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 10.67),
      children: const [
        GlassListSection(
          header: Text('Settings'),
          footer: Text('Footer text'),
          children: [
            GlassDisclosureGroup(
              leading: Icon(CupertinoIcons.gear),
              label: Text('Advanced'),
              initiallyExpanded: true,
              children: [
                GlassListTile(title: Text('Proxy'), value: 'Off'),
                GlassListTile(title: Text('DNS'), value: 'Automatic'),
              ],
            ),
            GlassDisclosureGroup(
              label: Text('Network'),
              children: [GlassListTile(title: Text('Wi-Fi'))],
            ),
          ],
        ),
      ],
    ),
  );
}

/// The "No Mail" empty state in the top 437 pt band, the search empty state
/// for "kiwi" in the bottom one, over white, ignoring the safe area.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Column(
      children: [
        const Expanded(
          child: Center(
            child: GlassEmptyState(
              icon: Icon(CupertinoIcons.tray),
              title: Text('No Mail'),
              description: Text('New messages you receive will appear here.'),
              actions: [GlassButton(onPressed: _noop, child: Text('Refresh'))],
            ),
          ),
        ),
        Expanded(
          child: Center(child: GlassEmptyState.search(query: 'kiwi')),
        ),
      ],
    ),
  );
}

/// The search empty state for "kiwi" in the top 437 pt band, "No Mail"
/// without actions in the bottom one, over white.
class _EmptyStateSwap extends StatelessWidget {
  const _EmptyStateSwap();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Column(
      children: [
        Expanded(
          child: Center(child: GlassEmptyState.search(query: 'kiwi')),
        ),
        const Expanded(
          child: Center(
            child: GlassEmptyState(
              icon: Icon(CupertinoIcons.tray),
              title: Text('No Mail'),
              description: Text('New messages you receive will appear here.'),
            ),
          ),
        ),
      ],
    ),
  );
}

/// A white "Home" page that, 0.3 s after launch, presents the full-screen
/// cover: a Done glass button top-trailing and a bold large "Cover" title
/// centred.
class _FullScreenCover extends StatefulWidget {
  const _FullScreenCover();

  @override
  State<_FullScreenCover> createState() => _FullScreenCoverState();
}

class _FullScreenCoverState extends State<_FullScreenCover> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      showGlassFullScreenCover<void>(
        context: context,
        builder: (context) => Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Spacer(),
                  GlassButton(onPressed: _noop, child: const Text('Done')),
                ],
              ),
            ),
            const Spacer(),
            const Text(
              'Cover',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.white,
    child: SizedBox.expand(child: Center(child: Text('Home'))),
  );
}

/// The linear battery gauge above the temp and battery rings, the column
/// centred at 201, 300, over white, ignoring the safe area.
class _Gauge extends StatelessWidget {
  const _Gauge();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: Stack(
      children: [
        _at(
          201,
          300,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 300,
                child: GlassGauge(
                  value: 0.62,
                  label: Text('Battery'),
                  currentValueLabel: Text('62%'),
                  minimumValueLabel: Text('0'),
                  maximumValueLabel: Text('100'),
                ),
              ),
              const SizedBox(height: 48),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassGauge(
                    value: 21,
                    min: 0,
                    max: 40,
                    style: GlassGaugeStyle.accessoryCircular,
                    label: Text('Temp'),
                    currentValueLabel: Text('21'),
                    minimumValueLabel: Text('0'),
                    maximumValueLabel: Text('40'),
                    tint: GlassSystemColors.orange,
                  ),
                  SizedBox(width: 48),
                  GlassGauge(
                    value: 0.62,
                    style: GlassGaugeStyle.accessoryCircularCapacity,
                    label: Text('Battery'),
                    currentValueLabel: Text('62'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
