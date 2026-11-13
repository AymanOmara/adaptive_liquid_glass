import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flutter twins of the `-listform <scene>` SwiftUI references
/// (example/ios/Runner/ListFormScenes.swift); null for other scenes.
/// Append `dark` to a scene for its dark appearance.
Widget? listFormTwin(String scene) {
  final dark = scene.endsWith('dark');
  final base = dark ? scene.substring(0, scene.length - 4) : scene;
  final Widget? twin = switch (base) {
    'sidebar' => const _SidebarTwin(tagsOpen: true),
    'sidebarcollapsed' => const _SidebarTwin(tagsOpen: false),
    'sidebarsplit' => const _SidebarSplitTwin(),
    _ => null,
  };
  if (twin == null) return null;
  return _NoStatusBar(dark: dark, child: twin);
}

/// Hides the status bar, as the references do, and applies [dark].
class _NoStatusBar extends StatefulWidget {
  const _NoStatusBar({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  State<_NoStatusBar> createState() => _NoStatusBarState();
}

class _NoStatusBarState extends State<_NoStatusBar> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  @override
  Widget build(BuildContext context) {
    final child = CupertinoTheme(
      data: CupertinoThemeData(
        brightness: widget.dark ? Brightness.dark : Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
      ),
      child: widget.child,
    );
    if (!widget.dark) return child;
    // The whole page dark, Material theme included (the Scaffold's
    // background and default text), as the SwiftUI reference under a dark
    // system appearance.
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(platformBrightness: Brightness.dark),
      child: Theme(
        data: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: CupertinoColors.black,
        ),
        child: child,
      ),
    );
  }
}

/// The reference's sections: Library (Inbox selected) and Tags.
List<GlassSidebarSection<String>> _sections({
  required bool libraryOpen,
  required bool tagsOpen,
  required ValueChanged<bool> onLibrary,
  required ValueChanged<bool> onTags,
}) => [
  GlassSidebarSection(
    header: const Text('Library'),
    isExpanded: libraryOpen,
    onExpansionChanged: onLibrary,
    items: const [
      GlassSidebarItem(
        value: 'Inbox',
        title: Text('Inbox'),
        icon: Icon(CupertinoIcons.tray),
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
    header: const Text('Tags'),
    isExpanded: tagsOpen,
    onExpansionChanged: onTags,
    items: const [
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
];

class _SidebarTwin extends StatefulWidget {
  const _SidebarTwin({required this.tagsOpen});

  final bool tagsOpen;

  @override
  State<_SidebarTwin> createState() => _SidebarTwinState();
}

class _SidebarTwinState extends State<_SidebarTwin> {
  String _selection = 'Inbox';
  bool _library = true;
  late bool _tags = widget.tagsOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GlassSidebarList<String>(
      selection: _selection,
      onSelectionChanged: (v) => setState(() => _selection = v),
      sections: _sections(
        libraryOpen: _library,
        tagsOpen: _tags,
        onLibrary: (v) => setState(() => _library = v),
        onTags: (v) => setState(() => _tags = v),
      ),
    ),
  );
}

class _SidebarSplitTwin extends StatefulWidget {
  const _SidebarSplitTwin();

  @override
  State<_SidebarSplitTwin> createState() => _SidebarSplitTwinState();
}

class _SidebarSplitTwinState extends State<_SidebarSplitTwin> {
  String _selection = 'Inbox';
  bool _library = true;
  bool _tags = true;

  @override
  Widget build(BuildContext context) => Scaffold(
    // UIKit's system background, not Material's tinted surface.
    backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
    body: GlassSplitView(
      sidebar: GlassSidebarList<String>(
        selection: _selection,
        onSelectionChanged: (v) => setState(() => _selection = v),
        sections: _sections(
          libraryOpen: _library,
          tagsOpen: _tags,
          onLibrary: (v) => setState(() => _library = v),
          onTags: (v) => setState(() => _tags = v),
        ),
      ),
      // SwiftUI's detail: body text centred in the space the floating
      // sidebar leaves.
      detail: SafeArea(
        top: false,
        bottom: false,
        child: Center(
          child: Text(
            _selection,
            style: TextStyle(
              fontSize: 17,
              letterSpacing: -0.43,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
        ),
      ),
    ),
  );
}
