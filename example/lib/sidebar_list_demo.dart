import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// `GlassSidebarList` showcase: a mail-style sidebar in a
/// `GlassSplitView` (side by side on iPad, stacked on iPhone). Run with
/// `flutter run -t lib/sidebar_list_demo.dart`.
Future<void> main() async {
  await AdaptiveLiquidGlass.initialize();
  runApp(const MaterialApp(home: SidebarListDemo()));
}

/// The demo page.
class SidebarListDemo extends StatefulWidget {
  /// Creates the page.
  const SidebarListDemo({super.key});

  @override
  State<SidebarListDemo> createState() => _SidebarListDemoState();
}

class _SidebarListDemoState extends State<SidebarListDemo> {
  String _selection = 'Inbox';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GlassSplitView(
      sidebar: GlassSidebarList<String>(
        selection: _selection,
        onSelectionChanged: (v) => setState(() => _selection = v),
        sections: const [
          GlassSidebarSection(
            header: Text('Library'),
            items: [
              GlassSidebarItem(
                value: 'Inbox',
                title: Text('Inbox'),
                icon: Icon(CupertinoIcons.tray),
                badge: '12',
              ),
              GlassSidebarItem(
                value: 'Drafts',
                title: Text('Drafts'),
                icon: Icon(CupertinoIcons.doc),
              ),
              GlassSidebarItem(
                value: 'Sent',
                title: Text('Sent'),
                icon: Icon(CupertinoIcons.paperplane),
              ),
            ],
          ),
          GlassSidebarSection(
            header: Text('Tags'),
            items: [
              GlassSidebarItem(
                value: 'Work',
                title: Text('Work'),
                icon: Icon(CupertinoIcons.folder),
              ),
              GlassSidebarItem(
                value: 'Family',
                title: Text('Family'),
                icon: Icon(CupertinoIcons.folder),
              ),
            ],
          ),
        ],
      ),
      detail: Center(child: Text(_selection)),
    ),
  );
}
