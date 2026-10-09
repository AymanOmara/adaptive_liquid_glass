# adaptive_liquid_glass example

A small app built from the package's main widgets: a navigation bar, a
floating tab bar with a badge, glass text, a merged pair of glass buttons,
a toggle, a slider, a sheet and a toast. On iOS 26+ it is SwiftUI's own
Liquid Glass, on older iOS the shader glass, and on Android Material 3, with
no platform checks in the code.

Run it from `example/`:

```sh
flutter run -t lib/quick_start.dart
```

More entry points:

- `flutter run`: a demo screen and a gallery with one recipe per README
  cookbook section (`lib/gallery.dart`).
- `flutter run -t lib/components_demo.dart`: every component on one screen.
- `flutter run -t lib/native_demo.dart`: SwiftUI's own glass (iOS 26+).

## `lib/quick_start.dart`

```dart
import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

// A small app built from the package's main widgets, shown on pub.dev's
// Example tab: `flutter run -t lib/quick_start.dart`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdaptiveLiquidGlass.initialize();
  runApp(const QuickStartApp());
}

/// The app: one glass screen, light and dark.
class QuickStartApp extends StatelessWidget {
  /// Creates the app.
  const QuickStartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(),
      darkTheme: ThemeData(brightness: Brightness.dark),
      home: const QuickStartScreen(),
    );
  }
}

/// A screen with a navigation bar, a tab bar and a few glass controls.
class QuickStartScreen extends StatefulWidget {
  /// Creates the screen.
  const QuickStartScreen({super.key});

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  int _tab = 0;
  bool _wifi = true;
  double _volume = 0.5;

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      navigationBar: GlassNavigationBar(
        title: const Text('Liquid Glass'),
        actions: [
          GlassButton.icon(
            onPressed: () => showGlassToast(
              context,
              message: 'Shared',
              icon: CupertinoIcons.checkmark_circle,
            ),
            icon: CupertinoIcons.share,
            semanticLabel: 'Share',
          ),
        ],
      ),
      tabBar: GlassTabBar(
        items: const [
          GlassTabBarItem(icon: CupertinoIcons.house_fill, label: 'Home'),
          GlassTabBarItem(
            icon: CupertinoIcons.bell_fill,
            label: 'Alerts',
            badge: '3',
          ),
          GlassTabBarItem(icon: CupertinoIcons.gear_solid, label: 'Settings'),
        ],
        selectedIndex: _tab,
        onSelected: (i) => setState(() => _tab = i),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/backgrounds/photo.png', fit: BoxFit.cover),
          Builder(
            // The body's padding includes the bars; read it below the
            // scaffold.
            builder: (context) => ListView(
              padding: MediaQuery.paddingOf(context)
                  .add(const EdgeInsetsDirectional.all(20)),
              children: [
                const Text('Hello, glass')
                    .glassEffect(padding: const EdgeInsets.all(16)),
                const SizedBox(height: 20),
                GlassGroup(
                  spacing: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      LiquidGlass(
                        shape: const GlassShape.circle(),
                        padding: const EdgeInsets.all(14),
                        onPressed: () {},
                        child: const Icon(CupertinoIcons.pencil),
                      ),
                      LiquidGlass(
                        glass: Glass.regular.tint(Colors.blue),
                        shape: const GlassShape.circle(),
                        padding: const EdgeInsets.all(14),
                        onPressed: () {},
                        child: const Icon(CupertinoIcons.add),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GlassToggle(
                  value: _wifi,
                  onChanged: (v) => setState(() => _wifi = v),
                ),
                const SizedBox(height: 20),
                GlassSlider(
                  value: _volume,
                  onChanged: (v) => setState(() => _volume = v),
                ),
                const SizedBox(height: 20),
                LiquidGlass(
                  shape: const GlassShape.rect(20),
                  padding: const EdgeInsetsDirectional.all(16),
                  onPressed: () => showGlassSheet<void>(
                    context: context,
                    detents: const [
                      GlassSheetDetent.medium,
                      GlassSheetDetent.large,
                    ],
                    builder: (context) =>
                        const Center(child: Text('Drag between detents')),
                  ),
                  child: const Text('Open a sheet'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```
