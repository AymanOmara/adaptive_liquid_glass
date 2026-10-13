import 'package:adaptive_liquid_glass/adaptive_liquid_glass.dart';
import 'package:adaptive_liquid_glass/src/platform/glass_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  });
}
