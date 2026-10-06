import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// `flutter run -t lib/components_demo.dart`: every component on one
/// `GlassScaffold`, over a photo. Add `--dart-define=MODE=shader` (or
/// `native`, `material`) to force a rendering path.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlass.precache();
  const mode = String.fromEnvironment('MODE');
  runApp(
    LiquidGlassTheme(
      data: LiquidGlassThemeData(
        defaultMode: switch (mode) {
          'shader' => GlassRenderMode.shader,
          'native' => GlassRenderMode.native,
          'material' => GlassRenderMode.material,
          _ => GlassRenderMode.auto,
        },
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        darkTheme: ThemeData(brightness: Brightness.dark),
        home: const ComponentsDemo(),
      ),
    ),
  );
}

enum _Period { day, week, month }

/// The components showcase.
class ComponentsDemo extends StatefulWidget {
  /// Creates the showcase.
  const ComponentsDemo({super.key});

  @override
  State<ComponentsDemo> createState() => _ComponentsDemoState();
}

class _ComponentsDemoState extends State<ComponentsDemo> {
  int _tab = 0;
  _Period _period = _Period.week;
  bool _wifi = true;
  double _volume = 0.6;
  bool _toolbar = false;

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => GlassScaffold(
    navigationBar: GlassNavigationBar(
      title: const Text('Components'),
      actions: [
        GlassMenuButton(
          icon: CupertinoIcons.ellipsis,
          semanticLabel: 'More',
          items: [
            GlassMenuItem(
              label: 'Copy',
              icon: CupertinoIcons.doc_on_doc,
              onSelected: () => _snack('Copy'),
            ),
            GlassMenuItem(
              label: 'Share',
              icon: CupertinoIcons.share,
              onSelected: () => _snack('Share'),
            ),
            GlassMenuItem(
              label: 'Delete',
              icon: CupertinoIcons.trash,
              destructive: true,
              onSelected: () => _snack('Delete'),
            ),
          ],
        ),
      ],
    ),
    tabBar: _toolbar
        ? null
        : GlassTabBar(
            items: const [
              GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
              GlassTabBarItem(icon: CupertinoIcons.music_note, label: 'Music'),
              GlassTabBarItem(
                icon: CupertinoIcons.gear_solid,
                label: 'Settings',
              ),
            ],
            selectedIndex: _tab,
            onSelected: (i) => setState(() => _tab = i),
          ),
    toolbar: _toolbar
        ? GlassToolbar(
            children: [
              GlassButton.icon(
                onPressed: () => _snack('Reply'),
                icon: CupertinoIcons.reply,
                semanticLabel: 'Reply',
              ),
              GlassButton.icon(
                onPressed: () => _snack('Flag'),
                icon: CupertinoIcons.flag,
                semanticLabel: 'Flag',
              ),
              const GlassToolbarSpacer(),
              GlassButton.icon(
                onPressed: () => _snack('Compose'),
                icon: CupertinoIcons.square_pencil,
                semanticLabel: 'Compose',
              ),
            ],
          )
        : null,
    bottomAccessory: GlassBottomAccessory(
      onPressed: () => _snack('Now Playing'),
      child: const Row(
        children: [
          Icon(CupertinoIcons.music_note_2, size: 20),
          SizedBox(width: 10),
          Expanded(child: Text('Liquid Glass — Now Playing')),
          Icon(CupertinoIcons.play_fill, size: 20),
        ],
      ),
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/backgrounds/photo.png', fit: BoxFit.cover),
        // The scaffold pads the body's MediaQuery by the bars; read it
        // below the scaffold, not with this State's context.
        Builder(
          builder: (context) => ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              20,
              16,
              20,
              24,
            ).add(MediaQuery.paddingOf(context)),
            children: [
              const GlassSearchField(),
              const SizedBox(height: 24),
              GlassSegmentedControl<_Period>(
                segments: const [
                  GlassSegment(value: _Period.day, label: Text('Day')),
                  GlassSegment(value: _Period.week, label: Text('Week')),
                  GlassSegment(value: _Period.month, label: Text('Month')),
                ],
                selected: _period,
                onChanged: (p) => setState(() => _period = p),
              ),
              const SizedBox(height: 24),
              LiquidGlass(
                shape: const GlassShape.rect(26),
                padding: const EdgeInsetsDirectional.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Wi-Fi')),
                        GlassToggle(
                          value: _wifi,
                          onChanged: (v) => setState(() => _wifi = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(CupertinoIcons.speaker_fill, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GlassSlider(
                            value: _volume,
                            onChanged: (v) => setState(() => _volume = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(CupertinoIcons.speaker_3_fill, size: 18),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Expanded(child: Text('Toolbar instead of tabs')),
                        GlassToggle(
                          value: _toolbar,
                          onChanged: (v) => setState(() => _toolbar = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: GlassButton(
                  onPressed: () => showGlassSheet<void>(
                    context: context,
                    builder: (context) => const Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Glass sheet',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text('Floats in from the edges; drag down to close.'),
                        ],
                      ),
                    ),
                  ),
                  child: const Text('Show sheet'),
                ),
              ),
              const SizedBox(height: 400),
            ],
          ),
        ),
      ],
    ),
  );
}
