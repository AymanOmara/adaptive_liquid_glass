import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// `GlassSplitView` (SwiftUI `NavigationSplitView`): columns side by side on
/// an iPad, one pushed column on an iPhone.
/// `flutter run -t lib/split_view_demo.dart`; `--dart-define=COLUMNS=3` for
/// the three-column form, `--dart-define=PICKED=1` to start with a mailbox
/// open, `--dart-define=MODE=material` for the Material path.
void main() async {
  await AdaptiveLiquidGlass.initialize(mode: GlassRenderMode.shader);
  runApp(const SplitViewDemo());
}

const _columns = int.fromEnvironment('COLUMNS', defaultValue: 2);
const _picked = int.fromEnvironment('PICKED', defaultValue: 0);

const _boxes = [
  ('Inbox', CupertinoIcons.tray, 12),
  ('Favorites', CupertinoIcons.star, 3),
  ('Sent', CupertinoIcons.paperplane, 0),
  ('Drafts', CupertinoIcons.doc, 2),
  ('Trash', CupertinoIcons.trash, 0),
];

/// The demo app.
class SplitViewDemo extends StatelessWidget {
  /// Creates it.
  const SplitViewDemo({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(debugShowCheckedModeBanner: false, home: const _Home());
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  late final _controller = GlassSplitViewController(
    compactColumn: _picked == 0
        ? GlassSplitViewColumn.sidebar
        : GlassSplitViewColumn.detail,
  );
  int _box = _picked == 0 ? 0 : _picked - 1;
  int _mail = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _sidebar() => Builder(
    builder: (context) => ListView(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            'Mailboxes',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        for (var i = 0; i < _boxes.length; i++)
          GlassListTile(
            leading: Icon(_boxes[i].$2),
            title: Text(_boxes[i].$1),
            value: _boxes[i].$3 == 0 ? null : '${_boxes[i].$3}',
            chevron: false,
            onTap: () {
              setState(() => _box = i);
              GlassSplitView.of(context).showColumn(
                _columns == 3
                    ? GlassSplitViewColumn.content
                    : GlassSplitViewColumn.detail,
              );
            },
          ),
      ],
    ),
  );

  Widget _content() => Builder(
    builder: (context) => GlassScaffold(
      navigationBar: GlassNavigationBar(
        title: Text(_boxes[_box].$1),
        leading: MediaQuery.sizeOf(context).width < 700
            ? GlassBackButton(
                onPressed: () =>
                    GlassSplitView.of(context)
                        .showColumn(GlassSplitViewColumn.sidebar),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 100),
        children: [
          for (var i = 0; i < 6; i++)
            GlassListTile(
              title: Text('Message ${i + 1}'),
              subtitle: const Text('Liquid Glass in Flutter'),
              onTap: () {
                setState(() => _mail = i);
                GlassSplitView.of(context)
                    .showColumn(GlassSplitViewColumn.detail);
              },
            ),
        ],
      ),
    ),
  );

  Widget _detail() => Builder(
    builder: (context) {
      final compact = MediaQuery.sizeOf(context).width < 700;
      return GlassScaffold(
        navigationBar: GlassNavigationBar(
          title: Text(_columns == 3 ? 'Message ${_mail + 1}' : _boxes[_box].$1),
          leading: compact
              ? GlassBackButton(
                  onPressed: () => GlassSplitView.of(context).showColumn(
                    _columns == 3
                        ? GlassSplitViewColumn.content
                        : GlassSplitViewColumn.sidebar,
                  ),
                )
              : null,
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7AA7FF), Color(0xFFFF9EC4), Color(0xFFFFD27A)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            _columns == 3 ? 'Message ${_mail + 1}' : _boxes[_box].$1,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) => GlassSplitView(
    controller: _controller,
    mode: const String.fromEnvironment('MODE') == 'material'
        ? GlassRenderMode.material
        : null,
    sidebar: _sidebar(),
    content: _columns == 3 ? _content() : null,
    detail: _detail(),
  );
}
