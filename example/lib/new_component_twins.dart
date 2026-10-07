import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Twins of the SwiftUI references for the newer components
/// (`ios/Runner/NewComponentScenes.swift`, same layout), for
/// `tool/reference/side_by_side.sh`. Null when [scene] is not one of them.
Widget? newComponentTwin(String scene) => switch (scene) {
  'disclosure' => const _Disclosure(),
  'emptystate' => const _EmptyState(),
  _ => null,
};

/// The buttons' no-op, as the SwiftUI scene's empty `Button` actions.
void _noop() {}


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
        Expanded(child: Center(child: GlassEmptyState.search(query: 'kiwi'))),
      ],
    ),
  );
}

