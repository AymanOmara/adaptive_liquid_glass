import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../api/hosts.dart';

void main() {
  tearDown(() => GlassPlatform.instance.debugReset());

  testWidgets('an M3 AppBar with the title and actions, no glass', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: GlassNavigationBar(
            title: const Text('Inbox'),
            actions: [
              GlassButton.icon(onPressed: () {}, icon: CupertinoIcons.pencil),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byType(LiquidGlass), findsNothing);
  }, variant: android);

  testWidgets('pushed route shows the Material back button', (t) async {
    shaderEnv();
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  appBar: GlassNavigationBar(title: Text('Detail')),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
  }, variant: android);

  group("the app's AppBarTheme (W7)", () {
    final theme = ThemeData(
      appBarTheme: const AppBarTheme(
        toolbarHeight: 64,
        backgroundColor: Colors.red,
      ),
    );

    testWidgets('in a Scaffold the bar is the theme height', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            appBar: GlassNavigationBar(title: Text('T')),
            body: SizedBox(),
          ),
        ),
      );
      expect(t.getSize(find.byType(AppBar)).height, 64);
    }, variant: android);

    testWidgets('in a GlassScaffold the bar is the theme height', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const GlassScaffold(
            navigationBar: GlassNavigationBar(title: Text('T')),
            body: SizedBox(),
          ),
        ),
      );
      expect(t.getSize(find.byType(AppBar)).height, 64);
    }, variant: android);

    testWidgets('the glass bar keeps its own height', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            appBar: GlassNavigationBar(title: Text('T')),
            body: SizedBox(),
          ),
        ),
      );
      expect(
        t.getSize(find.byType(GlassNavigationBar)).height,
        moreOrLessEquals(46.33, epsilon: 0.01),
      );
    }, variant: ios);

    testWidgets('every AppBarTheme style reaches the bar', (t) async {
      shaderEnv();
      const shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      );
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.red,
              foregroundColor: Colors.yellow,
              elevation: 3,
              shadowColor: Colors.green,
              surfaceTintColor: Colors.purple,
              shape: shape,
              centerTitle: true,
              titleSpacing: 30,
              toolbarHeight: 70,
              titleTextStyle: TextStyle(fontSize: 31, color: Colors.orange),
              toolbarTextStyle: TextStyle(fontSize: 13),
              iconTheme: IconThemeData(color: Colors.blue, size: 21),
              actionsIconTheme: IconThemeData(color: Colors.cyan, size: 23),
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
          ),
          home: Scaffold(
            appBar: GlassNavigationBar(
              title: const Text('T'),
              leading: const Icon(Icons.menu),
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
              ],
            ),
            body: const SizedBox(),
          ),
        ),
      );
      final material = t.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.red);
      expect(material.elevation, 3);
      expect(material.shadowColor, Colors.green);
      expect(material.surfaceTintColor, Colors.purple);
      expect(material.shape, shape);
      expect(t.getSize(find.byType(AppBar)).height, 70);
      final title = DefaultTextStyle.of(t.element(find.text('T'))).style;
      expect(title.fontSize, 31);
      expect(title.color, Colors.orange);
      final leading = IconTheme.of(t.element(find.byIcon(Icons.menu)));
      expect(leading.color, Colors.blue);
      expect(leading.size, 21);
      final action = IconTheme.of(t.element(find.byIcon(Icons.add)));
      expect(action.color, Colors.cyan);
      expect(action.size, 23);
      final toolbar = t.widget<NavigationToolbar>(
        find.byType(NavigationToolbar),
      );
      expect(toolbar.centerMiddle, isTrue);
      expect(toolbar.middleSpacing, 30);
      final overlay = t.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(overlay.value.statusBarBrightness, Brightness.dark);
    }, variant: android);

    testWidgets('foreground and scrolled-under elevation apply', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            appBarTheme: const AppBarTheme(
              foregroundColor: Colors.yellow,
              scrolledUnderElevation: 9,
            ),
          ),
          home: Scaffold(
            appBar: const GlassNavigationBar(
              title: Text('T'),
              leading: Icon(Icons.menu),
            ),
            body: ListView(children: const [SizedBox(height: 3000)]),
          ),
        ),
      );
      expect(
        IconTheme.of(t.element(find.byIcon(Icons.menu))).color,
        Colors.yellow,
      );
      await t.drag(find.byType(ListView), const Offset(0, -200));
      await t.pumpAndSettle();
      final material = t.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.elevation, 9);
    }, variant: android);

    testWidgets('explicit leading and title beat the theme', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            appBarTheme: const AppBarTheme(
              titleTextStyle: TextStyle(fontSize: 31),
            ),
          ),
          home: const Scaffold(
            appBar: GlassNavigationBar(
              title: Text('T', style: TextStyle(fontSize: 12)),
              leading: Icon(Icons.close),
            ),
          ),
        ),
      );
      expect(t.widget<Text>(find.text('T')).style!.fontSize, 12);
      expect(find.byIcon(Icons.close), findsOneWidget);
    }, variant: android);
  });

  group('materialBuilder', () {
    PreferredSizeWidget tall(AppBar bar) => AppBar(
      title: bar.title,
      leading: bar.leading,
      automaticallyImplyLeading: bar.automaticallyImplyLeading,
      actions: bar.actions,
      backgroundColor: Colors.green,
      toolbarHeight: 90,
    );

    testWidgets('replaces the bar and sizes the Scaffold slot', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            appBarTheme: const AppBarTheme(backgroundColor: Colors.red),
          ),
          home: Scaffold(
            appBar: GlassNavigationBar(
              title: const Text('T'),
              materialBuilder: tall,
            ),
            body: const SizedBox.expand(key: Key('body')),
          ),
        ),
      );
      final bar = t.widget<AppBar>(find.byType(AppBar));
      expect(bar.backgroundColor, Colors.green);
      expect(find.text('T'), findsOneWidget);
      expect(t.getSize(find.byType(AppBar)).height, 90);
      expect(t.getTopLeft(find.byKey(const Key('body'))).dy, 90);
    }, variant: android);

    testWidgets('can return any PreferredSizeWidget', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: GlassNavigationBar(
              title: const Text('T'),
              materialBuilder: (_) => const PreferredSize(
                preferredSize: Size.fromHeight(40),
                child: SizedBox.expand(child: Text('custom')),
              ),
            ),
            body: const SizedBox.expand(key: Key('body')),
          ),
        ),
      );
      expect(find.text('custom'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(t.getTopLeft(find.byKey(const Key('body'))).dy, 40);
    }, variant: android);

    testWidgets('sizes the bar in a GlassScaffold', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          home: GlassScaffold(
            navigationBar: GlassNavigationBar(
              title: const Text('T'),
              materialBuilder: tall,
            ),
            body: const SizedBox(),
          ),
        ),
      );
      expect(t.getSize(find.byType(AppBar)).height, 90);
    }, variant: android);

    testWidgets('the glass path ignores it', (t) async {
      shaderEnv();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: GlassNavigationBar(
              title: const Text('T'),
              materialBuilder: tall,
            ),
            body: const SizedBox(),
          ),
        ),
      );
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('T'), findsOneWidget);
      expect(
        t.getSize(find.byType(GlassNavigationBar)).height,
        moreOrLessEquals(46.33, epsilon: 0.01),
      );
    }, variant: ios);
  });
}
