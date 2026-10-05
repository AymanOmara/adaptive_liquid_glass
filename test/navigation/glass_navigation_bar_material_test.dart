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
}
