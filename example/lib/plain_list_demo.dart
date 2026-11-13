import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Twin of `PlainListReference` (`ios/Runner/ListFormScenes.swift`,
/// `-listform plain|plaindark|plainswipe`). Null when [scene] is not one.
Widget? plainListTwin(String scene) => switch (scene) {
  'plain' || 'plainswipe' => const PlainListDemo(),
  'plaindark' => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(platformBrightness: Brightness.dark),
      child: const CupertinoTheme(
        data: CupertinoThemeData(brightness: Brightness.dark),
        child: PlainListDemo(),
      ),
    ),
  ),
  _ => null,
};

/// A Mail-style plain list: swipeable mailboxes under a sticky header, then
/// a section with a leading icon and a two-line row.
class PlainListDemo extends StatefulWidget {
  /// Creates the demo.
  const PlainListDemo({super.key, this.extraRows = 0});

  /// Rows added to the first section, so it scrolls (sticky headers).
  final int extraRows;

  @override
  State<PlainListDemo> createState() => _PlainListDemoState();
}

class _PlainListDemoState extends State<PlainListDemo> {
  late final _boxes = [
    'Inbox',
    'Drafts',
    'Sent',
    'Junk',
    'Archive',
    'Trash',
    for (var i = 1; i <= widget.extraRows; i++) 'Folder $i',
  ];

  @override
  Widget build(BuildContext context) => GlassPlainList(
    sections: [
      GlassPlainListSection(
        header: const Text('Mailboxes'),
        children: [
          for (final box in _boxes)
            GlassSwipeActions(
              key: ValueKey(box),
              leading: [
                GlassSwipeAction(
                  icon: CupertinoIcons.envelope_badge,
                  label: 'Unread',
                  color: GlassSystemColors.blue,
                  onPressed: () {},
                ),
              ],
              trailing: [
                GlassSwipeAction(
                  icon: CupertinoIcons.trash,
                  label: 'Delete',
                  destructive: true,
                  onPressed: () => setState(() => _boxes.remove(box)),
                ),
                GlassSwipeAction(
                  icon: CupertinoIcons.flag_fill,
                  label: 'Flag',
                  color: GlassSystemColors.orange,
                  onPressed: () {},
                ),
              ],
              child: GlassListTile(title: Text(box), onTap: () {}),
            ),
        ],
      ),
      GlassPlainListSection(
        header: const Text('More'),
        children: [
          GlassListTile(
            leading: const Icon(CupertinoIcons.star),
            title: const Text('Favourites'),
            onTap: () {},
          ),
          const GlassListTile(
            title: Text('Subtitle row'),
            subtitle: Text('Secondary line'),
          ),
        ],
      ),
    ],
  );
}

/// The demo as a page with a back button; for the components page.
class PlainListDemoPage extends StatelessWidget {
  /// Creates the page.
  const PlainListDemoPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Plain list')),
    body: const PlainListDemo(extraRows: 20),
  );
}
