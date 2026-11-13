import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Flutter twins of the component-gap SwiftUI scenes (`-controls gap…`,
/// `GapScenes` in example/ios/Runner/ControlScenes.swift), laid out as
/// they are; null for other scenes. Launch with `-twin <scene>`, the
/// SwiftUI scene name with or without its `gap` prefix: `gapsubtitle`,
/// `gapsubtitleinline`, `gapedgehard`, `gapedgehidden`, `gaptransition`
/// (`gaptransitionhidden` starts with the glass hidden), `gapcontrolgroup`,
/// `gapsplit`. `hard` and `hidden` stay as aliases of the edge scenes.
Widget? gapTwin(String scene) {
  final name = scene.startsWith('gap') ? scene.substring(3) : scene;
  final Widget? page = switch (name) {
    'subtitle' => const _Subtitle(inline: false),
    'subtitleinline' => const _Subtitle(inline: true),
    'edgehard' ||
    'hard' => const _Subtitle(inline: false, edge: GlassScrollEdgeStyle.hard),
    'edgehidden' || 'hidden' => const _Subtitle(
      inline: false,
      edge: GlassScrollEdgeStyle.hidden,
    ),
    'transition' => const _Transition(shown: true),
    'transitionhidden' => const _Transition(shown: false),
    'controlgroup' => const _ControlGroup(),
    'split' => const _Split(),
    _ => null,
  };
  if (page == null) return null;
  // The SwiftUI scenes are light, on iOS's white system background.
  return Theme(
    data: ThemeData(
      scaffoldBackgroundColor: CupertinoColors.white,
      cupertinoOverrideTheme: const CupertinoThemeData(
        scaffoldBackgroundColor: CupertinoColors.white,
      ),
      // iOS 26's accent blue, the SwiftUI scenes' tint.
      colorScheme: const ColorScheme.light(primary: Color(0xFF0088FF)),
    ),
    child: CupertinoTheme(
      data: const CupertinoThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: CupertinoColors.white,
      ),
      child: page,
    ),
  );
}

/// SwiftUI's `.red, .pink, .purple, .indigo, .blue, .cyan, .teal, .green,
/// .mint, .yellow, .orange, .brown`: iOS 26 values where the package has
/// them, CupertinoColors (iOS 18) otherwise.
const _gapColors = [
  GlassSystemColors.red,
  CupertinoColors.systemPink,
  GlassSystemColors.purple,
  CupertinoColors.systemIndigo,
  GlassSystemColors.blue,
  GlassSystemColors.cyan,
  GlassSystemColors.teal,
  GlassSystemColors.green,
  CupertinoColors.systemMint,
  CupertinoColors.systemYellow,
  GlassSystemColors.orange,
  CupertinoColors.systemBrown,
];

/// The body text: 17 pt, as SwiftUI's `.body`.
const _body = TextStyle(
  fontSize: 17,
  letterSpacing: -0.43,
  color: CupertinoColors.black,
);

/// `GapSubtitle`: 80 semibold "Message i" rows under an "Inbox" title with
/// a "3 unread" subtitle and a trailing ellipsis button.
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.inline, this.edge});

  final bool inline;
  final GlassScrollEdgeStyle? edge;

  static Widget _row(BuildContext context, int i) => Padding(
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
    child: SizedBox(
      height: 56,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          'Message $i',
          style: _body.copyWith(
            fontWeight: FontWeight.w600,
            color: CupertinoDynamicColor.resolve(
              _gapColors[i % _gapColors.length],
              context,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final actions = [
      GlassButton.icon(
        onPressed: () {},
        icon: CupertinoIcons.ellipsis,
        semanticLabel: 'More',
      ),
    ];
    if (inline) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: GlassNavigationBar(
          title: const Text('Inbox'),
          subtitle: const Text('3 unread'),
          scrollEdgeStyle: edge ?? GlassScrollEdgeStyle.uniform,
          actions: actions,
        ),
        body: ListView.builder(
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + NavBarMetricsTwin.bar,
          ),
          itemCount: 80,
          itemBuilder: _row,
        ),
      );
    }
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverGlassNavigationBar(
            largeTitle: const Text('Inbox'),
            subtitle: const Text('3 unread'),
            scrollEdgeStyle: edge ?? GlassScrollEdgeStyle.uniform,
            actions: actions,
          ),
          SliverList.builder(itemCount: 80, itemBuilder: _row),
        ],
      ),
    );
  }
}

/// The inline bar's height, for the inline page's top padding.
abstract final class NavBarMetricsTwin {
  /// iOS 26's inline navigation bar height.
  static const double bar = 54;
}

const _transitionGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF3A7BD5), Color(0xFFE96443)],
);

/// `GapTransition`: a 22-pt "matchedGeometry" title, three 72-pt glass
/// circles 42 pt apart in a `GlassGroup` (spacing 24) of which the last
/// two use `GlassTransition.matchedGeometry`, and a prominent Hide/Show
/// button, 24 pt apart and centred.
class _Transition extends StatefulWidget {
  const _Transition({required this.shown});

  final bool shown;

  @override
  State<_Transition> createState() => _TransitionState();
}

class _TransitionState extends State<_Transition> {
  late bool _shown = widget.shown;

  Widget _circle(String id, IconData icon, {bool transition = false}) =>
      LiquidGlass(
        glassId: id,
        transition: transition
            ? GlassTransition.matchedGeometry
            : GlassTransition.identity,
        shape: const GlassShape.circle(),
        minSize: const Size.square(72),
        child: Icon(icon, size: 20, color: CupertinoColors.black),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DecoratedBox(
      decoration: const BoxDecoration(gradient: _transitionGradient),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'matchedGeometry',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              GlassGroup(
                spacing: 24,
                child: SizedBox(
                  width: 300,
                  height: 72,
                  child: Stack(
                    children: [
                      PositionedDirectional(
                        start: 0,
                        child: _circle('a', CupertinoIcons.star_fill),
                      ),
                      if (_shown)
                        PositionedDirectional(
                          start: 114,
                          child: _circle(
                            'b',
                            CupertinoIcons.heart_fill,
                            transition: true,
                          ),
                        ),
                      if (_shown)
                        PositionedDirectional(
                          start: 228,
                          child: _circle(
                            'c',
                            CupertinoIcons.bolt_fill,
                            transition: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              GlassButton(
                style: GlassButtonStyle.borderedProminent,
                onPressed: () => setState(() => _shown = !_shown),
                child: Text(_shown ? 'Hide' : 'Show'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// `GapControlGroup`: a 28-pt bold title and four groups under captions —
/// automatic (previous/next), navigation style (labelled Reply and Share
/// buttons, no capsule), three formatting members, and the menu style (an
/// "Actions" button that opens Copy and Delete).
class _ControlGroup extends StatefulWidget {
  const _ControlGroup();

  @override
  State<_ControlGroup> createState() => _ControlGroupState();
}

class _ControlGroupState extends State<_ControlGroup> {
  int _match = 1;

  Widget _icon(IconData icon, String label, [VoidCallback? onTap]) =>
      GlassButton.icon(
        onPressed: onTap ?? () {},
        icon: icon,
        semanticLabel: label,
      );

  /// A labelled borderless button, as `.controlGroupStyle(.navigation)`
  /// draws its members outside a toolbar.
  Widget _labelled(IconData icon, String label) => GlassButton.icon(
    onPressed: () {},
    style: GlassButtonStyle.borderless,
    icon: icon,
    label: Text(label),
    foregroundColor: CupertinoColors.systemBlue,
  );

  Widget _caption(String text) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Text(
      text,
      style: _body.copyWith(
        color: CupertinoColors.white.withValues(alpha: 0.7),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SizedBox.expand(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3A7BD5), Color(0xFFF2994A), Color(0xFFEB5757)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              spacing: 10,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ControlGroup',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: CupertinoColors.white,
                  ),
                ),
                _caption('Automatic style — $_match of 5'),
                GlassControlGroup(
                  dividers: false,
                  children: [
                    _icon(
                      CupertinoIcons.chevron_up,
                      'Previous',
                      () => setState(() => _match = (_match - 1).clamp(1, 5)),
                    ),
                    _icon(
                      CupertinoIcons.chevron_down,
                      'Next',
                      () => setState(() => _match = (_match + 1).clamp(1, 5)),
                    ),
                  ],
                ),
                _caption('Without dividers (toolbar look)'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    _labelled(CupertinoIcons.reply, 'Reply'),
                    _labelled(CupertinoIcons.share, 'Share'),
                  ],
                ),
                _caption('Three members'),
                GlassControlGroup(
                  dividers: false,
                  children: [
                    _icon(CupertinoIcons.bold, 'Bold'),
                    _icon(CupertinoIcons.italic, 'Italic'),
                    _icon(CupertinoIcons.underline, 'Underline'),
                  ],
                ),
                _caption('Menu style'),
                _labelled(CupertinoIcons.ellipsis, 'Actions'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

const _boxes = [
  ('Inbox', CupertinoIcons.tray, 12),
  ('Favorites', CupertinoIcons.star, 3),
  ('Sent', CupertinoIcons.paperplane, 0),
  ('Drafts', CupertinoIcons.doc, 2),
  ('Trash', CupertinoIcons.trash, 0),
];

/// `GapSplit` (iPad): a "Mailboxes" sidebar with an inline title and the
/// sidebar toggle, nothing selected, and an "Inbox" detail on a gradient.
class _Split extends StatefulWidget {
  const _Split();

  @override
  State<_Split> createState() => _SplitState();
}

class _SplitState extends State<_Split> {
  final _controller = GlassSplitViewController();
  int? _picked;

  @override
  void initState() {
    super.initState();
    // The reference hides the status bar.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _sidebar() => DefaultTextStyle(style: _body, child: _sidebarColumn());

  Widget _sidebarColumn() => Column(
    children: [
      // The bar's items sit 21 pt down the panel, 12 pt above its middle.
      SizedBox(
        width: double.infinity,
        height: 54,
        child: Stack(
          alignment: const Alignment(0, -12 / 27),
          children: [
            const Text(
              'Mailboxes',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.black,
              ),
            ),
            const PositionedDirectional(
              end: 18.5,
              child: GlassSplitViewSidebarButton(
                foregroundColor: CupertinoColors.black,
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: GlassSidebarList<int>(
          selection: _picked,
          onSelectionChanged: (v) => setState(() => _picked = v),
          sections: [
            GlassSidebarSection(
              collapsible: false,
              items: [
                for (var i = 0; i < _boxes.length; i++)
                  GlassSidebarItem(
                    value: i,
                    title: Text(_boxes[i].$1),
                    icon: Icon(_boxes[i].$2),
                    badge: _boxes[i].$3 == 0 ? null : '${_boxes[i].$3}',
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _detail() {
    final name = _boxes[_picked ?? 0].$1;
    return GlassScaffold(
      navigationBar: GlassNavigationBar(title: Text(name)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7AA7FF), Color(0xFFFF9EC4), Color(0xFFFFD27A)],
          ),
        ),
        child: SizedBox.expand(
          // Only the gradient ignores the safe area, as SwiftUI's
          // `.ignoresSafeArea()`: the title centres below the bar.
          child: SafeArea(
            child: Center(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GlassSplitView(
    controller: _controller,
    sidebar: _sidebar(),
    detail: _detail(),
  );
}
